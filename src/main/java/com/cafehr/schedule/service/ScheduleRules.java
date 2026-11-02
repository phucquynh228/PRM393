package com.cafehr.schedule.service;

import com.cafehr.common.exception.BusinessException;
import com.cafehr.schedule.entity.ScheduleStatus;
import com.cafehr.schedule.entity.UserSchedule;
import com.cafehr.schedule.repository.UserScheduleRepository;
import com.cafehr.staff.view.StaffViews;
import com.cafehr.user.entity.Role;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.time.*;
import java.util.Objects;

@Service @RequiredArgsConstructor
public class ScheduleRules {
    private final UserScheduleRepository schedules;

    public void validate(UserSchedule schedule) {
        if (schedule.getUser() == null || schedule.getUser().getRole() != Role.STAFF
                || schedule.getDate() == null || schedule.getShift() == null) {
            throw new BusinessException("Lịch cần có ngày, ca và nhân viên hợp lệ");
        }
        if (!schedule.getShift().isActive()) throw new BusinessException("Mẫu ca đã ngừng sử dụng. Hãy chọn ca đang hoạt động");
        if (schedule.getUser().getEmploymentStatus() != com.cafehr.user.entity.EmploymentStatus.ACTIVE) {
            throw new BusinessException("Nhân viên chưa ở trạng thái đang làm việc");
        }
        if (StaffViews.store(schedule) != null && (StaffViews.store(schedule).getStatus() == com.cafehr.branch.entity.StoreStatus.CLOSED
                || schedule.getUser().getStore() == null || !schedule.isTemporaryTransfer()
                && !schedule.getUser().getStore().getId().equals(StaffViews.store(schedule).getId()))) {
            throw new BusinessException("Chi nhánh đã đóng hoặc nhân viên đã được điều chuyển");
        }
        if (schedule.getStatus() != ScheduleStatus.PENDING
                || !StaffViews.start(schedule).isAfter(LocalDateTime.now())) {
            throw new BusinessException("Chỉ phân công hoặc công bố ca chưa bắt đầu");
        }
        assertNoOverlap(schedule.getUser().getId(), schedule, schedule.getId());
    }

    public void assertNoOverlap(Long userId, UserSchedule incoming, Long excludedId) {
        boolean overlap = schedules.findByUserIdAndDateBetweenOrderByDateAscShiftStartTimeAsc(
                userId, incoming.getDate().minusDays(1), incoming.getDate().plusDays(1)).stream()
                .filter(s -> !Objects.equals(s.getId(), excludedId) && s.getStatus() != ScheduleStatus.ON_LEAVE && s.getStatus() != ScheduleStatus.CANCELLED)
                .anyMatch(s -> StaffViews.start(s).isBefore(StaffViews.end(incoming))
                        && StaffViews.start(incoming).isBefore(StaffViews.end(s)));
        if (overlap) throw new BusinessException("Nhân viên có ca chồng lấn thời gian, kể cả lịch nháp hoặc ca qua đêm");
    }
}
