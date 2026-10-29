package com.cafehr.schedule.service;

import com.cafehr.branch.entity.*;
import com.cafehr.branch.repository.StoreRepository;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.schedule.dto.RosterRequests;
import com.cafehr.schedule.entity.*;
import com.cafehr.schedule.repository.*;
import com.cafehr.staff.service.StaffRequestService;
import com.cafehr.staff.view.StaffViews;
import com.cafehr.user.entity.*;
import com.cafehr.user.repository.UserRepository;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.*;

@Service @RequiredArgsConstructor
public class FixedRosterService {
    private final UserRepository users;
    private final StoreRepository stores;
    private final ShiftRepository shifts;
    private final UserScheduleRepository schedules;
    private final ScheduleRules rules;
    private final StaffRequestService requests;
    private final EntityManager entityManager;

    @Transactional(readOnly = true)
    public List<Map<String, Object>> settings(Long managerId) { return views(scope(managerId, false)); }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> adminSettings(Long storeId) {
        var branches = storeId == null ? stores.findAll() : List.of(stores.findById(storeId)
                .orElseThrow(() -> new BusinessException("Không tìm thấy chi nhánh")));
        return branches.stream().sorted(Comparator.comparing(Store::getId))
                .map(s -> StaffViews.row("storeId", s.getId(), "storeName", s.getName(), "plans", views(s))).toList();
    }

    @Transactional
    public List<Map<String, Object>> saveSettings(Long managerId, RosterRequests.Settings body) {
        Store store = scope(managerId, true);
        var plans = new EnumMap<ShiftSlot, BranchShiftPlan>(ShiftSlot.class);
        var ids = new HashSet<Long>();
        for (var input : body.slots()) {
            if (plans.containsKey(input.slot())) throw new BusinessException("Mỗi buổi chỉ có một cấu hình ca");
            if (input.shiftId() == null && input.requiredStaff() > 0) throw new BusinessException("Chọn mẫu ca trước khi đặt định mức");
            if (input.shiftId() != null) {
                activeShift(input.shiftId());
                if (!ids.add(input.shiftId())) throw new BusinessException("Không dùng cùng mẫu ca cho hai buổi");
            }
            plans.put(input.slot(), new BranchShiftPlan(input.shiftId(), input.requiredStaff()));
        }
        if (plans.size() != 3) throw new BusinessException("Cần cấu hình đủ Sáng, Chiều và Tối");
        store.getShiftPlans().clear(); store.getShiftPlans().putAll(plans);
        return views(store);
    }

    @Transactional
    public Map<String, Object> assign(Long managerId, RosterRequests.Batch body) {
        Store store = scope(managerId, true);
        Shift shift = planShift(store, body.slot());
        if (new HashSet<>(body.userIds()).size() != body.userIds().size()) throw new BusinessException("Danh sách nhân viên bị trùng");
        int existing = 0;
        var pending = new ArrayList<UserSchedule>();
        for (Long id : body.userIds().stream().sorted().toList()) {
            User user = staff(id, store);
            boolean assigned = schedules.findByUserIdAndDate(user.getId(), body.date()).stream()
                    .anyMatch(s -> StaffViews.slot(s) == body.slot() && s.getStatus() != ScheduleStatus.CANCELLED
                            && s.getStatus() != ScheduleStatus.ON_LEAVE);
            if (assigned) { existing++; continue; }
            try {
                requests.assertNoLeave(id, body.date());
                var schedule = draft(user, store, shift, body.date(), body.slot());
                rules.validate(schedule); pending.add(schedule);
            } catch (BusinessException ex) {
                throw new BusinessException(user.getName() + ": " + ex.getMessage());
            }
        }
        schedules.saveAll(pending);
        return StaffViews.row("created", pending.size(), "existing", existing);
    }

    @Transactional
    public Map<String, Object> generate(Long managerId, LocalDate monday) {
        Store store = scope(managerId, true);
        if (monday.getDayOfWeek() != DayOfWeek.MONDAY || monday.plusDays(6).isBefore(LocalDate.now())
                || monday.isAfter(LocalDate.now().plusYears(1))) {
            throw new BusinessException("Chọn thứ Hai của tuần hiện tại hoặc tuần tương lai trong 1 năm");
        }
        int created = 0, existing = 0;
        var skipped = new ArrayList<Map<String, Object>>();
        var staffIds = users.findByStoreId(store.getId()).stream().filter(FixedRosterService::activeStaff)
                .map(User::getId).sorted().toList();
        // Branch lock serializes generation/batch and branch lifecycle changes. User locks also coordinate leave approval.
        var staff = staffIds.stream().map(id -> staff(id, store)).toList();
        for (User user : staff) {
            var preferences = user.getFixedRoster().stream().sorted(Comparator.comparingInt(FixedRosterEntry::getDayOfWeek)
                    .thenComparing(FixedRosterEntry::getSlot)).toList();
            for (var entry : preferences) {
                LocalDate date = monday.plusDays(entry.getDayOfWeek() - 1);
                // Preserve existing assignments and explicit leave/cancellations when generating again.
                if (schedules.findByUserIdAndDate(user.getId(), date).stream().anyMatch(s -> StaffViews.slot(s) == entry.getSlot())) {
                    existing++; continue;
                }
                try {
                    Shift shift = planShift(store, entry.getSlot());
                    requests.assertNoLeave(user.getId(), date);
                    var draft = draft(user, store, shift, date, entry.getSlot());
                    rules.validate(draft); schedules.save(draft); created++;
                } catch (BusinessException ex) {
                    skipped.add(StaffViews.row("userId", user.getId(), "userName", user.getName(),
                            "date", date, "slot", entry.getSlot().name(), "reason", ex.getMessage()));
                }
            }
        }
        return StaffViews.row("weekStart", monday, "created", created, "existing", existing, "skipped", skipped);
    }

    private static UserSchedule draft(User user, Store store, Shift shift, LocalDate date, ShiftSlot slot) {
        return UserSchedule.builder().user(user).store(store).shift(shift).date(date).shiftSlot(slot)
                .status(ScheduleStatus.PENDING).published(false).build();
    }

    private Store scope(Long managerId, boolean write) {
        User manager = users.findById(managerId).filter(u -> u.getRole() == Role.MANAGER && u.getStore() != null
                && u.getEmploymentStatus() == EmploymentStatus.ACTIVE)
                .orElseThrow(() -> new BusinessException("Tài khoản chưa được gán vào chi nhánh quản lý"));
        Store store = (write ? stores.findLockedById(manager.getStore().getId()) : stores.findById(manager.getStore().getId()))
                .orElseThrow(() -> new BusinessException("Không tìm thấy chi nhánh"));
        if (write) {
            entityManager.refresh(store); entityManager.refresh(manager);
            if (manager.getRole() != Role.MANAGER || manager.getEmploymentStatus() != EmploymentStatus.ACTIVE
                    || manager.getStore() == null || !manager.getStore().getId().equals(store.getId())) {
                throw new BusinessException("Phân công chi nhánh của quản lý đã thay đổi. Vui lòng tải lại");
            }
        }
        if (store.getStatus() == StoreStatus.CLOSED) throw new BusinessException("Chi nhánh đã ngừng hoạt động");
        return store;
    }

    private User staff(Long id, Store store) {
        User user = users.findLockedById(id).orElseThrow(() -> new BusinessException("Không tìm thấy nhân viên"));
        entityManager.refresh(user);
        if (!activeStaff(user) || user.getStore() == null || !user.getStore().getId().equals(store.getId())) {
            throw new BusinessException("Nhân viên không thuộc chi nhánh đang quản lý");
        }
        return user;
    }

    private static boolean activeStaff(User user) { return user.getRole() == Role.STAFF && user.getEmploymentStatus() == EmploymentStatus.ACTIVE; }

    private Shift activeShift(Long id) {
        return shifts.findById(id).filter(Shift::isActive).orElseThrow(() -> new BusinessException("Mẫu ca chưa được chọn hoặc đã ngừng sử dụng"));
    }

    private Shift planShift(Store store, ShiftSlot slot) {
        Long id = plans(store).get(slot).getShiftId();
        if (id == null) throw new BusinessException("Chưa cấu hình mẫu cho " + slot.label());
        return activeShift(id);
    }

    private Map<ShiftSlot, BranchShiftPlan> plans(Store store) {
        var result = new EnumMap<ShiftSlot, BranchShiftPlan>(ShiftSlot.class);
        var active = shifts.findAll().stream().filter(Shift::isActive).sorted(Comparator.comparing(Shift::getStartTime).thenComparing(Shift::getId)).toList();
        for (ShiftSlot slot : ShiftSlot.values()) {
            var fallback = active.stream().filter(s -> ShiftSlot.fromStart(s.getStartTime()) == slot).findFirst().orElse(null);
            result.put(slot, store.getShiftPlans().getOrDefault(slot, new BranchShiftPlan(fallback == null ? null : fallback.getId(), 0)));
        }
        return result;
    }

    private List<Map<String, Object>> views(Store store) {
        return plans(store).entrySet().stream().map(entry -> {
            Shift shift = entry.getValue().getShiftId() == null ? null : shifts.findById(entry.getValue().getShiftId()).orElse(null);
            return StaffViews.row("slot", entry.getKey().name(), "label", entry.getKey().label(),
                    "shiftId", shift == null ? null : shift.getId(), "shiftName", shift == null ? null : shift.getName(),
                    "startTime", shift == null ? null : shift.getStartTime(), "endTime", shift == null ? null : shift.getEndTime(),
                    "active", shift != null && shift.isActive(), "requiredStaff", entry.getValue().getRequiredStaff());
        }).toList();
    }
}
