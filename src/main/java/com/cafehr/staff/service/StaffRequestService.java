package com.cafehr.staff.service;

import com.cafehr.attendance.entity.Attendance;
import com.cafehr.attendance.repository.AttendanceRepository;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.notification.service.StaffNotificationService;
import com.cafehr.schedule.entity.ScheduleStatus;
import com.cafehr.schedule.entity.UserSchedule;
import com.cafehr.schedule.repository.UserScheduleRepository;
import com.cafehr.staff.dto.BranchRequestCreate;
import com.cafehr.staff.entity.BranchRequest;
import com.cafehr.staff.entity.BranchRequestStatus;
import com.cafehr.staff.entity.BranchRequestType;
import com.cafehr.staff.repository.BranchRequestRepository;
import com.cafehr.staff.view.StaffViews;
import com.cafehr.user.entity.Role;
import com.cafehr.user.entity.User;
import com.cafehr.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.*;
import static com.cafehr.staff.view.StaffViews.*;

@Service @RequiredArgsConstructor
public class StaffRequestService {
    private final BranchRequestRepository requests;
    private final UserScheduleRepository schedules;
    private final AttendanceRepository attendance;
    private final StaffWorkspaceService workspace;
    private final StaffNotificationService notifications;
    private final UserRepository users;

    @Transactional
    public Map<String, Object> create(Long userId, BranchRequestCreate body) {
        User user = workspace.staff(userId);
        if (user.getStore() == null) throw new BusinessException("Tài khoản chưa được gán vào chi nhánh");
        String reason = body.getReason().trim();
        if (reason.isEmpty() || reason.length() > 1000) throw new BusinessException("Lý do cần từ 1 đến 1000 ký tự");
        BranchRequest item = BranchRequest.builder().user(user).type(body.getType())
                .startDate(body.getStartDate()).endDate(body.getEndDate()).reason(reason).build();
        if (body.getType() == BranchRequestType.SHIFT_SWAP) {
            UserSchedule source = ownedSchedule(body.getSourceScheduleId(), userId);
            UserSchedule target = schedule(body.getTargetScheduleId());
            validateSwap(source, target, user);
            item.setSourceScheduleId(source.getId());
            item.setTargetScheduleId(target.getId());
            item.setSourceShiftId(source.getShift().getId());
            item.setTargetShiftId(target.getShift().getId());
            item.setTargetUserId(target.getUser().getId());
            item.setStartDate(source.getDate());
            item.setEndDate(target.getDate());
        } else if (body.getType() == BranchRequestType.ATTENDANCE_CORRECTION) {
            UserSchedule source = ownedSchedule(body.getSourceScheduleId(), userId);
            validateCorrection(source, body.getRequestedCheckIn(), body.getRequestedCheckOut());
            item.setSourceScheduleId(source.getId());
            item.setSourceShiftId(source.getShift().getId());
            item.setRequestedCheckIn(body.getRequestedCheckIn());
            item.setRequestedCheckOut(body.getRequestedCheckOut());
            item.setStartDate(source.getDate());
            item.setEndDate(source.getDate());
        } else {
            validateLeave(item);
        }
        boolean duplicate = requests.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .anyMatch(r -> r.getStatus() == BranchRequestStatus.PENDING && r.getType() == item.getType()
                        && Objects.equals(r.getSourceScheduleId(), item.getSourceScheduleId())
                        && r.getStartDate().equals(item.getStartDate()) && r.getEndDate().equals(item.getEndDate()));
        if (duplicate) throw new BusinessException("Bạn đã có yêu cầu tương tự đang chờ duyệt");
        requests.save(item);
        return request(item);
    }

    @Transactional
    public Map<String, Object> cancel(Long userId, Long id) {
        BranchRequest item = lockedRequest(id);
        if (!item.getUser().getId().equals(userId)) throw new BusinessException("Yêu cầu không thuộc về bạn");
        if (!canCancel(item)) throw new BusinessException("Yêu cầu đã xử lý hoặc quá hạn hủy");
        item.setStatus(BranchRequestStatus.CANCELLED);
        return request(item);
    }

    @Transactional
    public Map<String, Object> decide(Long storeId, Long id, BranchRequestStatus status, String note) {
        if (status != BranchRequestStatus.APPROVED && status != BranchRequestStatus.REJECTED) {
            throw new BusinessException("Chỉ có thể duyệt hoặc từ chối yêu cầu");
        }
        if (note != null && note.length() > 1000) throw new BusinessException("Ghi chú tối đa 1000 ký tự");
        if (status == BranchRequestStatus.REJECTED && (note == null || note.isBlank())) {
            throw new BusinessException("Vui lòng nhập lý do từ chối");
        }
        BranchRequest item = lockedRequest(id);
        if (item.getUser().getStore() == null || !item.getUser().getStore().getId().equals(storeId)) {
            throw new BusinessException("Không tìm thấy yêu cầu trong chi nhánh");
        }
        if (item.getStatus() != BranchRequestStatus.PENDING) throw new BusinessException("Yêu cầu này đã được xử lý");
        if (status == BranchRequestStatus.APPROVED) {
            switch (item.getType()) {
                case LEAVE, UNPAID_LEAVE -> approveLeave(item);
                case SHIFT_SWAP -> approveSwap(item);
                case ATTENDANCE_CORRECTION -> approveCorrection(item);
            }
        }
        item.setStatus(status);
        item.setManagerNote(note == null ? null : note.trim());
        notifications.send(item.getUser(), status == BranchRequestStatus.APPROVED ? "Yêu cầu đã được duyệt" : "Yêu cầu bị từ chối",
                "Đơn #" + item.getId() + " · " + item.getStartDate() + (note == null || note.isBlank() ? "" : "\n" + note.trim()), "REQUEST");
        return request(item);
    }

    public void assertNoLeave(Long userId, LocalDate date) {
        boolean onLeave = requests.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .anyMatch(r -> r.getStatus() == BranchRequestStatus.APPROVED && isLeave(r)
                        && !date.isBefore(r.getStartDate()) && !date.isAfter(r.getEndDate()));
        if (onLeave) throw new BusinessException("Nhân viên đã được duyệt nghỉ trong ngày này");
    }

    private void validateLeave(BranchRequest item) {
        if (item.getStartDate().isBefore(LocalDate.now()) || item.getEndDate().isBefore(item.getStartDate())
                || item.getEndDate().isAfter(item.getStartDate().plusDays(30))) {
            throw new BusinessException("Ngày nghỉ phải từ hôm nay, tối đa 31 ngày mỗi đơn");
        }
        for (LocalDate date = item.getStartDate(); !date.isAfter(item.getEndDate()); date = date.plusDays(1)) {
            assertNoLeave(item.getUser().getId(), date);
        }
        List<UserSchedule> affected = schedules.findByUserIdAndDateBetweenAndPublishedTrueOrderByDateAscShiftStartTimeAsc(
                item.getUser().getId(), item.getStartDate(), item.getEndDate());
        if (affected.stream().anyMatch(s -> !start(s).isAfter(LocalDateTime.now()) || attendance.findByScheduleId(s.getId()).isPresent())) {
            throw new BusinessException("Không thể xin nghỉ cho ca đã bắt đầu hoặc đã chấm công");
        }
    }

    private void approveLeave(BranchRequest item) {
        users.findLockedById(item.getUser().getId()).orElseThrow();
        validateLeave(item);
        schedules.findByUserIdAndDateBetweenAndPublishedTrueOrderByDateAscShiftStartTimeAsc(
                item.getUser().getId(), item.getStartDate(), item.getEndDate()).forEach(s -> {
            UserSchedule locked = schedule(s.getId());
            if (locked.getStatus() != ScheduleStatus.PENDING) throw new BusinessException("Ca làm đã thay đổi, không thể duyệt nghỉ");
            locked.setStatus(ScheduleStatus.ON_LEAVE);
        });
    }

    private void validateSwap(UserSchedule source, UserSchedule target, User user) {
        if (!source.getUser().getId().equals(user.getId()) || source.getId().equals(target.getId())
                || target.getUser().getId().equals(user.getId()) || target.getUser().getRole() != Role.STAFF
                || target.getUser().getStore() == null || user.getStore() == null
                || !target.getUser().getStore().getId().equals(user.getStore().getId())) {
            throw new BusinessException("Chỉ đổi với ca của nhân viên khác trong cùng chi nhánh");
        }
        for (UserSchedule shift : List.of(source, target)) {
            if (!shift.isPublished() || shift.getStatus() != ScheduleStatus.PENDING || !start(shift).isAfter(LocalDateTime.now())
                    || attendance.findByScheduleId(shift.getId()).isPresent()) {
                throw new BusinessException("Chỉ đổi ca đã công bố, chưa bắt đầu và chưa chấm công");
            }
        }
        assertNoLeave(source.getUser().getId(), target.getDate());
        assertNoLeave(target.getUser().getId(), source.getDate());
        assertNoOverlap(source.getUser().getId(), target, source.getId());
        assertNoOverlap(target.getUser().getId(), source, target.getId());
    }

    private void assertNoOverlap(Long userId, UserSchedule incoming, Long removed) {
        boolean overlap = schedules.findByUserIdAndDateBetweenOrderByDateAscShiftStartTimeAsc(
                userId, incoming.getDate().minusDays(1), incoming.getDate().plusDays(1)).stream()
                .filter(s -> !s.getId().equals(removed) && s.getStatus() != ScheduleStatus.ON_LEAVE)
                .anyMatch(s -> start(s).isBefore(end(incoming)) && start(incoming).isBefore(end(s)));
        if (overlap) throw new BusinessException("Đổi ca sẽ gây trùng lịch làm việc");
    }

    private void approveSwap(BranchRequest item) {
        if (item.getSourceScheduleId() == null || item.getTargetScheduleId() == null) {
            throw new BusinessException("Đơn đổi ca cũ thiếu ca cụ thể. Nhân viên cần gửi lại đơn mới");
        }
        // Stable lock order for requests involving the same pair.
        java.util.stream.Stream.of(item.getUser().getId(), item.getTargetUserId()).distinct().sorted()
                .forEach(id -> users.findLockedById(id).orElseThrow());
        schedule(Math.min(item.getSourceScheduleId(), item.getTargetScheduleId()));
        schedule(Math.max(item.getSourceScheduleId(), item.getTargetScheduleId()));
        UserSchedule source = ownedSchedule(item.getSourceScheduleId(), item.getUser().getId());
        UserSchedule target = schedule(item.getTargetScheduleId());
        if (!source.getDate().equals(item.getStartDate()) || !target.getDate().equals(item.getEndDate())
                || !source.getShift().getId().equals(item.getSourceShiftId()) || !target.getShift().getId().equals(item.getTargetShiftId())
                || !target.getUser().getId().equals(item.getTargetUserId())) {
            throw new BusinessException("Ca làm đã thay đổi từ lúc gửi đơn. Vui lòng gửi lại yêu cầu");
        }
        validateSwap(source, target, item.getUser());
        User other = target.getUser();
        source.setUser(other);
        target.setUser(item.getUser());
        notifications.scheduleChanged(source, "Quản lý đã duyệt đổi ca");
        notifications.scheduleChanged(target, "Quản lý đã duyệt đổi ca");
    }

    private void validateCorrection(UserSchedule source, LocalDateTime checkIn, LocalDateTime checkOut) {
        LocalDate today = LocalDate.now();
        if (!source.isPublished() || source.getDate().isBefore(today.minusDays(30)) || source.getDate().isAfter(today)
                || source.getStatus() == ScheduleStatus.ON_LEAVE) {
            throw new BusinessException("Chỉ sửa công cho ca đã công bố trong 30 ngày gần đây và không phải ca nghỉ phép");
        }
        if (checkIn == null || checkOut == null || !checkOut.isAfter(checkIn)
                || checkIn.isBefore(source.getDate().atStartOfDay()) || checkIn.isAfter(end(source).plusHours(12))
                || checkOut.isAfter(LocalDateTime.now()) || Duration.between(checkIn, checkOut).compareTo(Duration.ofHours(24)) > 0) {
            throw new BusinessException("Nhập đủ giờ vào/ra hợp lệ, không ở tương lai và thời lượng tối đa 24 giờ");
        }
    }

    private void approveCorrection(BranchRequest item) {
        UserSchedule source = ownedSchedule(item.getSourceScheduleId(), item.getUser().getId());
        if (!source.getShift().getId().equals(item.getSourceShiftId())) throw new BusinessException("Ca làm đã thay đổi từ lúc gửi đơn");
        validateCorrection(source, item.getRequestedCheckIn(), item.getRequestedCheckOut());
        boolean overlap = attendance.findByUserIdOrderByCheckInTimeDesc(item.getUser().getId()).stream()
                .filter(a -> !a.getSchedule().getId().equals(source.getId()))
                .anyMatch(a -> a.getCheckInTime().isBefore(item.getRequestedCheckOut())
                        && (a.getCheckOutTime() == null || a.getCheckOutTime().isAfter(item.getRequestedCheckIn())));
        if (overlap) throw new BusinessException("Giờ đề xuất trùng với bản ghi chấm công khác");
        Attendance record = attendance.findByScheduleId(source.getId()).orElseGet(() -> Attendance.builder()
                .user(item.getUser()).schedule(source).build());
        record.setCheckInTime(item.getRequestedCheckIn());
        record.setCheckOutTime(item.getRequestedCheckOut());
        record.setManuallyAdjusted(true);
        attendance.save(record);
        source.setStatus(ScheduleStatus.CHECKED_OUT);
    }

    private boolean isLeave(BranchRequest r) { return r.getType() == BranchRequestType.LEAVE || r.getType() == BranchRequestType.UNPAID_LEAVE; }
    private BranchRequest lockedRequest(Long id) {
        return requests.findLockedById(id).orElseThrow(() -> new BusinessException("Không tìm thấy yêu cầu"));
    }
    private UserSchedule schedule(Long id) {
        if (id == null) throw new BusinessException("Vui lòng chọn ca làm cụ thể");
        return schedules.findLockedById(id).orElseThrow(() -> new BusinessException("Không tìm thấy ca làm"));
    }
    private UserSchedule ownedSchedule(Long id, Long userId) {
        UserSchedule schedule = schedule(id);
        if (!schedule.getUser().getId().equals(userId)) throw new BusinessException("Ca làm không thuộc về bạn");
        return schedule;
    }
}
