package com.cafehr.branch.service;

import com.cafehr.attendance.repository.AttendanceRepository;
import com.cafehr.branch.dto.*;
import com.cafehr.branch.entity.*;
import com.cafehr.branch.repository.StoreRepository;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.notification.service.StaffNotificationService;
import com.cafehr.schedule.entity.*;
import com.cafehr.schedule.repository.UserScheduleRepository;
import com.cafehr.staff.entity.*;
import com.cafehr.staff.repository.BranchRequestRepository;
import com.cafehr.staff.view.StaffViews;
import com.cafehr.user.entity.*;
import com.cafehr.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDateTime;
import java.util.*;
import static com.cafehr.staff.view.StaffViews.row;

@Service @RequiredArgsConstructor
public class BranchLifecycleService {
    private final StoreRepository stores;
    private final UserRepository users;
    private final UserScheduleRepository schedules;
    private final AttendanceRepository attendance;
    private final BranchRequestRepository requests;
    private final StaffNotificationService notifications;
    private final jakarta.persistence.EntityManager entityManager;

    @Transactional(readOnly = true)
    public Map<String, Object> preview(Long storeId) {
        Store store = store(storeId);
        List<User> members = users.findByStoreId(storeId);
        Map<Long, User> working = new LinkedHashMap<>();
        members.stream().filter(u -> attendance.existsByUserIdAndCheckOutTimeIsNull(u.getId())).forEach(u -> working.put(u.getId(), u));
        attendance.findByScheduleStoreIdAndCheckOutTimeIsNull(storeId).forEach(a -> working.put(a.getUser().getId(), a.getUser()));
        return row("id", store.getId(), "name", store.getName(), "status", store.getStatus(),
                "employees", members.stream().filter(u -> u.getRole() != Role.ADMIN).map(StaffViews::profile).toList(),
                "adminAccounts", members.stream().filter(u -> u.getRole() == Role.ADMIN).count(),
                "futureSchedules", schedules.findByStoreIdOrderByDateAscShiftStartTimeAsc(storeId).stream().filter(this::remaining).count(),
                "pendingRequests", requests.findByStoreIdOrderByCreatedAtDesc(storeId).stream().filter(r -> r.getStatus() == BranchRequestStatus.PENDING).count(),
                "openAttendances", working.size(), "workingEmployees", working.values().stream().map(u -> row("id", u.getId(), "name", u.getName())).toList(),
                "canDelete", canDelete(storeId));
    }

    @Transactional
    public Map<String, Object> close(Long storeId, BranchClosureRequest body) {
        Set<Long> storeIds = new TreeSet<>(); storeIds.add(storeId);
        body.getPlacements().stream().map(EmployeePlacement::getTargetStoreId).filter(Objects::nonNull).forEach(storeIds::add);
        Map<Long, Store> locked = lockStores(storeIds);
        Store source = locked.get(storeId);
        if (source.getStatus() == StoreStatus.CLOSED) throw new BusinessException("Chi nhánh đã ngừng hoạt động");
        List<User> members = users.findByStoreId(storeId).stream().sorted(Comparator.comparing(User::getId))
                .map(u -> lockUser(u.getId())).toList();
        Map<Long, User> affected = new LinkedHashMap<>();
        members.stream().filter(u -> u.getRole() != Role.ADMIN).forEach(u -> affected.put(u.getId(), u));
        Set<Long> submitted = new HashSet<>();
        for (EmployeePlacement placement : body.getPlacements()) {
            if (!submitted.add(placement.getUserId()) || !affected.containsKey(placement.getUserId())) {
                throw new BusinessException("Danh sách xử lý nhân viên bị trùng hoặc đã thay đổi. Hãy tải lại");
            }
        }
        if (!submitted.equals(affected.keySet())) throw new BusinessException("Cần chọn cách xử lý cho tất cả nhân viên và Manager");
        for (User user : members) assertNoOpenAttendance(user);
        if (!attendance.findByScheduleStoreIdAndCheckOutTimeIsNull(storeId).isEmpty()) {
            throw new BusinessException("Chi nhánh còn ca đang chấm công; cần check-out trước khi đóng");
        }
        validatePlacements(affected, body.getPlacements(), locked, storeId);
        String reason = "Chi nhánh " + source.getName() + " ngừng hoạt động: " + body.getReason().trim();
        for (User user : members) snapshotHistory(user);
        for (UserSchedule schedule : schedules.findByStoreIdOrderByDateAscShiftStartTimeAsc(storeId)) cancelSchedule(schedule, reason);
        requests.findByStoreIdOrderByCreatedAtDesc(storeId).forEach(r -> cancelRequest(r, reason));
        members.forEach(this::clearManagerAssignments);
        source.setManager(null);
        stores.flush();
        for (EmployeePlacement placement : body.getPlacements()) apply(affected.get(placement.getUserId()), placement, locked, reason);
        // Admin affiliation does not grant branch management; keep the account usable.
        members.stream().filter(u -> u.getRole() == Role.ADMIN).forEach(u -> u.setStore(null));
        source.setStatus(StoreStatus.CLOSED);
        source.setClosedAt(LocalDateTime.now());
        source.setClosureReason(body.getReason().trim());
        return row("storeId", storeId, "status", source.getStatus(), "processedEmployees", affected.size());
    }

    @Transactional
    public Map<String, Object> place(Long userId, EmployeePlacement placement) {
        if (!userId.equals(placement.getUserId())) throw new BusinessException("Nhân viên không hợp lệ");
        User initial = users.findById(userId).orElseThrow(() -> new BusinessException("Không tìm thấy nhân viên"));
        Set<Long> ids = new TreeSet<>();
        if (initial.getStore() != null) ids.add(initial.getStore().getId());
        if (placement.getTargetStoreId() != null) ids.add(placement.getTargetStoreId());
        Map<Long, Store> locked = lockStores(ids);
        User user = lockUser(userId);
        if (user.getRole() == Role.ADMIN) throw new BusinessException("Không dùng luồng nhân sự để ngừng hoặc điều chuyển Admin");
        assertNoOpenAttendance(user);
        validatePlacements(Map.of(userId, user), List.of(placement), locked,
                user.getStore() == null ? null : user.getStore().getId());
        snapshotHistory(user);
        clearManagerAssignments(user); stores.flush();
        apply(user, placement, locked, "Admin cập nhật bố trí nhân sự");
        return StaffViews.profile(user);
    }

    private void validatePlacements(Map<Long, User> members, List<EmployeePlacement> placements,
            Map<Long, Store> locked, Long sourceId) {
        Map<Long, Integer> incoming = new HashMap<>(), incomingManagers = new HashMap<>();
        for (EmployeePlacement p : placements) {
            if (p.getAction() == null) throw new BusinessException("Chọn cách xử lý nhân viên");
            if (p.getAction() != EmployeePlacement.Action.TRANSFER) {
                if (p.getTargetStoreId() != null || p.isManager()) throw new BusinessException("Chỉ điều chuyển mới được chọn chi nhánh và quyền quản lý");
                continue;
            }
            Store target = locked.get(p.getTargetStoreId());
            if (target == null || Objects.equals(target.getId(), sourceId) || target.getStatus() != StoreStatus.ACTIVE) {
                throw new BusinessException("Chọn chi nhánh nhận đang hoạt động và khác chi nhánh hiện tại");
            }
            incoming.merge(target.getId(), 1, Integer::sum);
            if (p.isManager()) {
                incomingManagers.merge(target.getId(), 1, Integer::sum);
                if (target.getManager() != null && !target.getManager().getId().equals(p.getUserId())) {
                    throw new BusinessException("Chi nhánh " + target.getName() + " đã có Manager");
                }
            }
        }
        for (Map.Entry<Long, Integer> entry : incoming.entrySet()) {
            Store target = locked.get(entry.getKey());
            if (users.findByStoreId(target.getId()).size() + entry.getValue() > (target.getMaxStaff() == null ? 15 : target.getMaxStaff())) {
                throw new BusinessException("Chi nhánh " + target.getName() + " không đủ định biên để nhận nhóm nhân viên");
            }
            if (incomingManagers.getOrDefault(target.getId(), 0) > 1) throw new BusinessException("Mỗi chi nhánh chỉ có một Manager");
        }
    }

    private void apply(User user, EmployeePlacement placement, Map<Long, Store> locked, String reason) {
        schedules.findByUserIdOrderByDateAscShiftStartTimeAsc(user.getId()).forEach(s -> cancelSchedule(s, reason));
        requests.findPendingInvolvingUser(user.getId()).forEach(r -> cancelRequest(r, reason));
        user.setRole(placement.isManager() ? Role.MANAGER : Role.STAFF);
        if (placement.getAction() == EmployeePlacement.Action.TRANSFER) {
            Store target = locked.get(placement.getTargetStoreId());
            user.setStore(target); user.setEmploymentStatus(EmploymentStatus.ACTIVE);
            if (placement.isManager()) target.setManager(user);
        } else {
            user.setStore(null);
            user.setEmploymentStatus(placement.getAction() == EmployeePlacement.Action.INACTIVE ? EmploymentStatus.INACTIVE : EmploymentStatus.WAITING_TRANSFER);
        }
        notifications.send(user, "Cập nhật bố trí nhân sự", reason + "\n" +
                (user.getStore() == null ? user.getEmploymentStatus() == EmploymentStatus.INACTIVE ? "Tài khoản đã ngừng hoạt động" : "Bạn đang chờ điều chuyển" : "Chi nhánh mới: " + user.getStore().getName())
                + "\nCác ca sắp tới cũ đã hủy; quản lý sẽ phân công lịch mới.", "BRANCH");
    }

    private boolean remaining(UserSchedule s) {
        return (s.getStatus() == ScheduleStatus.PENDING || s.getStatus() == ScheduleStatus.ON_LEAVE)
                && StaffViews.end(s).isAfter(LocalDateTime.now());
    }

    private void cancelSchedule(UserSchedule schedule, String reason) {
        if (!remaining(schedule)) return;
        UserSchedule locked = schedules.findLockedById(schedule.getId()).orElseThrow();
        if (remaining(locked)) {
            if (attendance.findByScheduleId(locked.getId()).isPresent()) throw new BusinessException("Ca làm đã có chấm công; hãy kiểm tra lại");
            notifications.scheduleChanged(locked, "Ca làm đã hủy do thay đổi chi nhánh");
            locked.setStatus(ScheduleStatus.CANCELLED);
        }
    }

    private void cancelRequest(BranchRequest request, String reason) {
        if (request.getStatus() != BranchRequestStatus.PENDING) return;
        BranchRequest locked = requests.findLockedById(request.getId()).orElseThrow();
        if (locked.getStatus() == BranchRequestStatus.PENDING) {
            locked.setStatus(BranchRequestStatus.CANCELLED);
            locked.setManagerNote(reason);
            notifications.send(locked.getUser(), "Yêu cầu đã hủy", "Đơn #" + locked.getId() + ": " + reason, "REQUEST");
        }
    }

    private void snapshotHistory(User user) {
        schedules.findByUserIdOrderByDateAscShiftStartTimeAsc(user.getId()).forEach(UserSchedule::captureStore);
        requests.findByUserIdOrderByCreatedAtDesc(user.getId()).forEach(BranchRequest::captureStore);
    }

    private void clearManagerAssignments(User user) {
        stores.findByManagerId(user.getId()).forEach(s -> s.setManager(null));
    }

    @Transactional
    public void assignManager(Long storeId, Long userId) {
        User candidate = users.findById(userId).orElseThrow(() -> new BusinessException("Không tìm thấy nhân viên"));
        Set<Long> ids = new TreeSet<>(); ids.add(storeId);
        if (candidate.getStore() != null) ids.add(candidate.getStore().getId());
        Store target = lockStores(ids).get(storeId);
        User user = lockUser(userId);
        if (user.getRole() == Role.ADMIN || user.getEmploymentStatus() != EmploymentStatus.ACTIVE
                || target.getStatus() != StoreStatus.ACTIVE) throw new BusinessException("Chỉ bổ nhiệm nhân viên và chi nhánh đang hoạt động");
        if (user.getStore() == null || !storeId.equals(user.getStore().getId())) {
            EmployeePlacement p = new EmployeePlacement(); p.setUserId(userId); p.setAction(EmployeePlacement.Action.TRANSFER); p.setTargetStoreId(storeId);
            place(userId, p);
        }
        User previous = target.getManager();
        if (previous != null && !previous.getId().equals(userId)) {
            previous.setRole(Role.STAFF);
            notifications.send(previous, "Thay đổi quyền quản lý", "Bạn tiếp tục làm nhân viên tại " + target.getName(), "BRANCH");
        }
        target.setManager(null);
        clearManagerAssignments(user); stores.flush();
        user.setRole(Role.MANAGER); user.setStore(target); target.setManager(user);
    }

    private void assertNoOpenAttendance(User user) {
        if (attendance.existsByUserIdAndCheckOutTimeIsNull(user.getId())) {
            throw new BusinessException(user.getName() + " còn ca chưa check-out; cần xử lý trước khi điều chuyển/ngừng làm việc");
        }
    }

    private Map<Long, Store> lockStores(Set<Long> ids) {
        entityManager.flush();
        Map<Long, Store> result = new LinkedHashMap<>();
        for (Long id : ids) {
            Store store = stores.findLockedById(id).orElseThrow(() -> new BusinessException("Không tìm thấy chi nhánh"));
            entityManager.refresh(store);
            result.put(id, store);
        }
        return result;
    }

    private User lockUser(Long id) {
        User user = users.findLockedById(id).orElseThrow(() -> new BusinessException("Không tìm thấy nhân viên"));
        entityManager.refresh(user);
        return user;
    }

    private Store store(Long id) { return stores.findById(id).orElseThrow(() -> new BusinessException("Không tìm thấy chi nhánh")); }

    @Transactional(readOnly = true)
    public boolean canDelete(Long id) {
        return users.findByStoreId(id).isEmpty() && !schedules.existsByStoreId(id) && !requests.existsByStoreId(id)
                && store(id).getManager() == null;
    }

    @Transactional
    public void deleteUnused(Long id) {
        stores.findLockedById(id).orElseThrow(() -> new BusinessException("Không tìm thấy chi nhánh"));
        if (!canDelete(id)) throw new BusinessException("Chỉ xóa vĩnh viễn chi nhánh chưa có nhân sự và lịch sử. Hãy dùng Ngừng hoạt động");
        stores.deleteById(id);
    }
}
