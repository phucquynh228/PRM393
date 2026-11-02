package com.cafehr.schedule.service;

import com.cafehr.attendance.repository.AttendanceRepository;
import com.cafehr.branch.entity.*;
import com.cafehr.branch.repository.StoreRepository;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.notification.service.StaffNotificationService;
import com.cafehr.schedule.entity.*;
import com.cafehr.schedule.repository.UserScheduleRepository;
import com.cafehr.staff.repository.BranchRequestRepository;
import com.cafehr.staff.service.StaffRequestService;
import com.cafehr.staff.view.StaffViews;
import com.cafehr.user.repository.UserRepository;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;

@Service @RequiredArgsConstructor
public class AdminRosterService {
    private final UserScheduleRepository schedules;
    private final StoreRepository stores;
    private final UserRepository users;
    private final AttendanceRepository attendance;
    private final BranchRequestRepository requests;
    private final StaffRequestService leave;
    private final ScheduleRules rules;
    private final StaffNotificationService notifications;
    private final EntityManager entityManager;

    @Transactional
    public Map<String, Object> transfer(Long id, Long sourceId, Long targetId) {
        if (Objects.equals(sourceId, targetId)) throw new BusinessException("Chọn chi nhánh nhận khác chi nhánh hiện tại");
        var initial = schedules.findById(id).orElseThrow(() -> new BusinessException("Không tìm thấy ca làm"));
        // Match lifecycle/batch lock order: branches, employee, assignment.
        var ids = new TreeSet<>(List.of(sourceId, targetId));
        if (initial.getUser().getStore() != null) ids.add(initial.getUser().getStore().getId());
        var locked = new HashMap<Long, Store>();
        for (Long storeId : ids) {
            var store = stores.findLockedById(storeId).orElseThrow(() -> new BusinessException("Không tìm thấy chi nhánh"));
            entityManager.refresh(store);
            locked.put(storeId, store);
        }
        var user = users.findLockedById(initial.getUser().getId()).orElseThrow();
        entityManager.refresh(user);
        var schedule = schedules.findLockedById(id).orElseThrow();
        entityManager.refresh(schedule);
        if (!schedule.getUser().getId().equals(user.getId()) || StaffViews.store(schedule) == null
                || !sourceId.equals(StaffViews.store(schedule).getId())) {
            throw new BusinessException("Ca làm đã thay đổi chi nhánh hoặc nhân viên. Vui lòng tải lại");
        }
        if (user.getStore() == null || !locked.containsKey(user.getStore().getId())
                || locked.get(user.getStore().getId()).getStatus() != StoreStatus.ACTIVE
                || locked.get(sourceId).getStatus() != StoreStatus.ACTIVE || locked.get(targetId).getStatus() != StoreStatus.ACTIVE) {
            throw new BusinessException("Chỉ điều chuyển giữa các chi nhánh đang hoạt động");
        }
        if (schedule.getStatus() != ScheduleStatus.PENDING || !StaffViews.start(schedule).isAfter(java.time.LocalDateTime.now())
                || attendance.findByScheduleId(id).isPresent()) {
            throw new BusinessException("Chỉ điều chuyển ca chưa bắt đầu và chưa chấm công");
        }
        if (requests.findPendingInvolvingUser(user.getId()).stream().anyMatch(r ->
                id.equals(r.getSourceScheduleId()) || id.equals(r.getTargetScheduleId()))) {
            throw new BusinessException("Ca có yêu cầu đang chờ duyệt. Hãy xử lý yêu cầu trước khi điều chuyển");
        }
        leave.assertNoLeave(user.getId(), schedule.getDate());
        var target = locked.get(targetId);
        schedule.setStore(target);
        schedule.setStoreName(target.getName());
        schedule.setStoreCode(target.getCode());
        schedule.setTemporaryTransfer(!targetId.equals(user.getStore().getId()));
        rules.validate(schedule);
        // Date, hours, employee and publication state are preserved.
        notifications.scheduleChanged(schedule, "Ca làm đã chuyển từ " + locked.get(sourceId).getName() + " sang " + target.getName());
        return StaffViews.schedule(schedule);
    }
}
