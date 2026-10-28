package com.cafehr.branch.controller;

import com.cafehr.attendance.entity.Attendance;
import com.cafehr.attendance.repository.AttendanceRepository;
import com.cafehr.branch.entity.Store;
import com.cafehr.branch.entity.StoreStatus;
import com.cafehr.branch.repository.StoreRepository;
import com.cafehr.common.dto.ApiResponse;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.notification.dto.AnnouncementRequest;
import com.cafehr.notification.service.StaffNotificationService;
import com.cafehr.schedule.controller.AdminScheduleController;
import com.cafehr.schedule.dto.ManagerScheduleRequest;
import com.cafehr.schedule.entity.ScheduleStatus;
import com.cafehr.schedule.entity.Shift;
import com.cafehr.schedule.entity.UserSchedule;
import com.cafehr.schedule.repository.ShiftRepository;
import com.cafehr.schedule.repository.UserScheduleRepository;
import com.cafehr.schedule.service.ScheduleRules;
import com.cafehr.staff.dto.BranchRequestDecision;
import com.cafehr.staff.entity.BranchRequest;
import com.cafehr.staff.repository.BranchRequestRepository;
import com.cafehr.staff.service.StaffRequestService;
import com.cafehr.staff.view.StaffViews;
import com.cafehr.user.dto.ManagerStaffRequest;
import com.cafehr.user.entity.Role;
import com.cafehr.user.entity.User;
import com.cafehr.user.repository.UserRepository;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/manager")
@RequiredArgsConstructor
@PreAuthorize("hasRole('MANAGER')")
public class BranchManagerController {

    private final UserRepository userRepository;
    private final StoreRepository storeRepository;
    private final ShiftRepository shiftRepository;
    private final UserScheduleRepository scheduleRepository;
    private final AttendanceRepository attendanceRepository;
    private final BranchRequestRepository branchRequestRepository;
    private final PasswordEncoder passwordEncoder;
    private final StaffRequestService staffRequestService;
    private final StaffNotificationService staffNotifications;
    private final ScheduleRules scheduleRules;
    private final jakarta.persistence.EntityManager entityManager;

    @GetMapping("/branch")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getBranch(HttpServletRequest request) {
        Store store = getManagerStore(request);
        List<Map<String, Object>> staff = userRepository.findByStoreId(store.getId()).stream()
                .filter(user -> user.getRole() == Role.STAFF && user.getEmploymentStatus() == com.cafehr.user.entity.EmploymentStatus.ACTIVE)
                .sorted(Comparator.comparing(User::getName, String.CASE_INSENSITIVE_ORDER))
                .map(this::staffResponse)
                .toList();
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("id", store.getId());
        response.put("code", store.getCode());
        response.put("name", store.getName());
        response.put("status", store.getStatus() != null ? store.getStatus().name() : "ACTIVE");
        response.put("staffCount", staff.size());
        response.put("maxStaff", store.getMaxStaff());
        response.put("managerName", store.getManager() != null ? store.getManager().getName() : null);
        response.put("staff", staff);
        return ResponseEntity.ok(ApiResponse.ok("Thông tin chi nhánh", response));
    }

    @GetMapping("/shifts")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getShifts() {
        List<Map<String, Object>> shifts = shiftRepository.findAll().stream()
                .filter(Shift::isActive)
                .sorted(Comparator.comparing(Shift::getStartTime))
                .map(AdminScheduleController::template)
                .toList();
        return ResponseEntity.ok(ApiResponse.ok("Danh sách ca làm", shifts));
    }

    @GetMapping("/schedules")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getSchedules(
            HttpServletRequest request,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to) {
        Store store = getManagerStore(request);
        validateRange(from, to);
        List<Map<String, Object>> schedules = scheduleRepository
                .findByStoreIdAndDateBetweenOrderByDateAscShiftStartTimeAsc(store.getId(), from, to)
                .stream().map(this::scheduleResponse).toList();
        return ResponseEntity.ok(ApiResponse.ok("Lịch phân ca", schedules));
    }

    @PostMapping("/schedules")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> createSchedule(
            HttpServletRequest request,
            @Valid @RequestBody ManagerScheduleRequest body) {
        Store store = getManagerStore(request);
        if (body.getDate().isBefore(LocalDate.now())) {
            throw new BusinessException("Không thể tạo lịch trong quá khứ");
        }
        User staff = getStaffInStore(body.getUserId(), store);
        staffRequestService.assertNoLeave(staff.getId(), body.getDate());
        Shift shift = shiftRepository.findById(body.getShiftId())
                .orElseThrow(() -> new BusinessException("Không tìm thấy ca làm"));
        UserSchedule schedule = UserSchedule.builder()
                .user(staff)
                .shift(shift)
                .date(body.getDate())
                .status(ScheduleStatus.PENDING)
                .published(body.isPublished())
                .build();
        scheduleRules.validate(schedule);
        scheduleRepository.save(schedule);
        String message = body.isPublished() ? "Đã tạo và công bố lịch" : "Đã tạo lịch nháp";
        staffNotifications.scheduleChanged(schedule, "Bạn được phân công ca làm mới");
        return ResponseEntity.ok(ApiResponse.ok(message, scheduleResponse(schedule)));
    }

    @PutMapping("/schedules/{id}")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateSchedule(
            HttpServletRequest request,
            @PathVariable Long id,
            @Valid @RequestBody ManagerScheduleRequest body) {
        Store store = getManagerStore(request);
        UserSchedule schedule = scheduleRepository.findById(id)
                .filter(item -> StaffViews.store(item) != null
                        && StaffViews.store(item).getId().equals(store.getId()))
                .orElseThrow(() -> new BusinessException("Không tìm thấy lịch trong chi nhánh"));
        if (body.getDate().isBefore(LocalDate.now())) {
            throw new BusinessException("Không thể sửa lịch trong quá khứ");
        }
        if (schedule.getStatus() != ScheduleStatus.PENDING
                || !StaffViews.start(schedule).isAfter(java.time.LocalDateTime.now())
                || attendanceRepository.findByScheduleId(id).isPresent()) {
            throw new BusinessException("Không thể sửa ca đã bắt đầu chấm công");
        }
        User staff = getStaffInStore(body.getUserId(), store);
        staffRequestService.assertNoLeave(staff.getId(), body.getDate());
        Shift shift = shiftRepository.findById(body.getShiftId())
                .orElseThrow(() -> new BusinessException("Không tìm thấy ca làm"));
        if (schedule.isPublished() && !schedule.getUser().getId().equals(staff.getId())) {
            staffNotifications.scheduleChanged(schedule, "Ca làm của bạn đã được chuyển cho nhân viên khác");
        }
        if (schedule.isPublished() && !body.isPublished()) {
            staffNotifications.scheduleChanged(schedule, "Ca làm tạm thu hồi để điều chỉnh");
        }
        schedule.setUser(staff);
        if (!schedule.getShift().getId().equals(shift.getId())) schedule.setShiftSlot(null);
        schedule.setShift(shift);
        schedule.setDate(body.getDate());
        schedule.setPublished(body.isPublished());
        scheduleRules.validate(schedule);
        String message = body.isPublished() ? "Đã cập nhật và công bố lịch" : "Đã cập nhật lịch nháp";
        staffNotifications.scheduleChanged(schedule, "Lịch làm của bạn đã thay đổi");
        return ResponseEntity.ok(ApiResponse.ok(message, scheduleResponse(schedule)));
    }

    @DeleteMapping("/schedules/{id}")
    @Transactional
    public ResponseEntity<ApiResponse<Void>> deleteSchedule(
            HttpServletRequest request,
            @PathVariable Long id) {
        Store store = getManagerStore(request);
        UserSchedule schedule = scheduleRepository.findById(id)
                .filter(item -> StaffViews.store(item) != null
                        && StaffViews.store(item).getId().equals(store.getId()))
                .orElseThrow(() -> new BusinessException("Không tìm thấy lịch trong chi nhánh"));
        if (schedule.getStatus() != ScheduleStatus.PENDING
                || !StaffViews.start(schedule).isAfter(java.time.LocalDateTime.now())
                || attendanceRepository.findByScheduleId(id).isPresent()) {
            throw new BusinessException("Không thể xóa ca đã bắt đầu chấm công");
        }
        staffNotifications.scheduleChanged(schedule, "Ca làm đã được quản lý hủy");
        if (schedule.getShiftSlot() != null && !schedule.isPublished()) {
            // Keep an explicit omission so generating this week again does not undo the manager's adjustment.
            schedule.setStatus(ScheduleStatus.CANCELLED);
        } else {
            scheduleRepository.delete(schedule);
        }
        return ResponseEntity.ok(ApiResponse.ok("Đã xóa lịch", null));
    }

    @PostMapping("/schedules/{id}/publish")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> publishSchedule(
            HttpServletRequest request,
            @PathVariable Long id) {
        Store store = getManagerStore(request);
        UserSchedule schedule = scheduleRepository.findById(id)
                .filter(item -> StaffViews.store(item) != null
                        && StaffViews.store(item).getId().equals(store.getId()))
                .orElseThrow(() -> new BusinessException("Không tìm thấy lịch trong chi nhánh"));
        userRepository.findLockedById(schedule.getUser().getId()).orElseThrow();
        staffRequestService.assertNoLeave(schedule.getUser().getId(), schedule.getDate());
        scheduleRules.validate(schedule);
        boolean wasPublished = schedule.isPublished();
        schedule.setPublished(true);
        if (!wasPublished) staffNotifications.scheduleChanged(schedule, "Lịch làm của bạn đã được công bố");
        return ResponseEntity.ok(ApiResponse.ok("Đã công bố lịch cho nhân viên", scheduleResponse(schedule)));
    }

    @PostMapping("/schedules/publish")
    @Transactional
    public ResponseEntity<ApiResponse<Integer>> publishRange(HttpServletRequest request,
            @RequestParam LocalDate from, @RequestParam LocalDate to) {
        Store store = getManagerStore(request);
        validateRange(from, to);
        List<UserSchedule> drafts = scheduleRepository
                .findByStoreIdAndDateBetweenOrderByDateAscShiftStartTimeAsc(store.getId(), from, to)
                .stream().filter(s -> !s.isPublished() && s.getStatus() == ScheduleStatus.PENDING).toList();
        drafts.stream().map(s -> s.getUser().getId()).distinct().sorted()
                .forEach(id -> userRepository.findLockedById(id).orElseThrow());
        for (UserSchedule schedule : drafts) {
            staffRequestService.assertNoLeave(schedule.getUser().getId(), schedule.getDate());
            scheduleRules.validate(schedule);
        }
        for (UserSchedule schedule : drafts) {
            schedule.setPublished(true);
            staffNotifications.scheduleChanged(schedule, "Lịch làm của bạn đã được công bố");
        }
        return ResponseEntity.ok(ApiResponse.ok("Đã công bố lịch hợp lệ", drafts.size()));
    }

    @PostMapping("/staff")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> createStaff(
            HttpServletRequest request,
            @Valid @RequestBody ManagerStaffRequest body) {
        Store store = getManagerStore(request);
        if (store.getStatus() == StoreStatus.CLOSED) {
            throw new BusinessException("Chi nhánh đã ngừng hoạt động");
        }
        if (userRepository.existsByPhone(body.getPhone().trim())) {
            throw new BusinessException("Số điện thoại đã tồn tại trong hệ thống");
        }
        long staffCount = userRepository.findByStoreId(store.getId()).stream()
                .filter(user -> user.getRole() == Role.STAFF).count();
        if (staffCount >= store.getMaxStaff()) {
            throw new BusinessException("Chi nhánh đã đạt định biên nhân sự tối đa");
        }
        String rawPassword = body.getPassword() == null || body.getPassword().isBlank()
                ? "123456" : body.getPassword();
        User staff = userRepository.save(User.builder()
                .name(body.getName().trim())
                .phone(body.getPhone().trim())
                .password(passwordEncoder.encode(rawPassword))
                .role(Role.STAFF)
                .store(store)
                .build());
        applyFixedRoster(staff, body);
        return ResponseEntity.ok(ApiResponse.ok("Đã tạo hồ sơ nhân viên", staffResponse(staff)));
    }

    @PutMapping("/staff/{id}")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateStaff(
            HttpServletRequest request,
            @PathVariable Long id,
            @Valid @RequestBody ManagerStaffRequest body) {
        Store store = getManagerStore(request);
        User staff = getStaffInStore(id, store);
        String phone = body.getPhone().trim();
        if (!staff.getPhone().equals(phone) && userRepository.existsByPhone(phone)) {
            throw new BusinessException("Số điện thoại đã tồn tại trong hệ thống");
        }
        staff.setName(body.getName().trim());
        applyFixedRoster(staff, body);
        staff.setPhone(phone);
        if (body.getPassword() != null && !body.getPassword().isBlank()) {
            staff.setPassword(passwordEncoder.encode(body.getPassword()));
            staff.setDeviceId(null);
        }
        return ResponseEntity.ok(ApiResponse.ok("Đã cập nhật hồ sơ nhân viên", staffResponse(staff)));
    }

    @GetMapping("/attendance")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getAttendance(
            HttpServletRequest request,
            @RequestParam LocalDate date) {
        Store store = getManagerStore(request);
        List<Attendance> attendance = attendanceRepository
                .findByScheduleStoreIdAndCheckInTimeBetweenOrderByCheckInTimeDesc(
                        store.getId(), date.atStartOfDay(), date.plusDays(1).atStartOfDay());
        Map<Long, Attendance> bySchedule = attendance.stream().collect(
                java.util.stream.Collectors.toMap(item -> item.getSchedule().getId(), item -> item));
        List<UserSchedule> schedules = scheduleRepository
                .findByStoreIdAndDateBetweenAndPublishedTrueOrderByDateAscShiftStartTimeAsc(
                        store.getId(), date, date).stream().filter(s -> s.getStatus() != ScheduleStatus.CANCELLED).toList();
        List<Map<String, Object>> records = schedules.stream().map(schedule -> {
            Attendance record = bySchedule.get(schedule.getId());
            if (record != null) return attendanceResponse(record);
            Map<String, Object> response = new LinkedHashMap<>();
            response.put("id", null);
            response.put("userId", schedule.getUser().getId());
            response.put("userName", schedule.getUser().getName());
            response.put("shiftName", schedule.getShift().getName());
            response.put("checkInTime", null);
            response.put("checkOutTime", null);
            response.put("status", schedule.getStatus() == ScheduleStatus.ON_LEAVE ? "ON_LEAVE"
                    : schedule.getStatus() == ScheduleStatus.ABSENT || StaffViews.end(schedule).isBefore(java.time.LocalDateTime.now())
                    ? "ABSENT" : "NOT_CHECKED_IN");
            return response;
        }).toList();
        long checkedIn = attendance.size();
        long checkedOut = attendance.stream().filter(item -> item.getCheckOutTime() != null).count();
        long absent = records.stream().filter(item -> "ABSENT".equals(item.get("status"))).count();
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("date", date);
        response.put("total", schedules.size());
        response.put("checkedIn", checkedIn);
        response.put("checkedOut", checkedOut);
        response.put("absent", absent);
        response.put("records", records);
        return ResponseEntity.ok(ApiResponse.ok("Chấm công trong ngày", response));
    }

    @GetMapping("/reports")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getReport(
            HttpServletRequest request,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to) {
        Store store = getManagerStore(request);
        validateRange(from, to);
        List<UserSchedule> schedules = scheduleRepository
                .findByStoreIdAndDateBetweenAndPublishedTrueOrderByDateAscShiftStartTimeAsc(
                        store.getId(), from, to).stream().filter(s -> s.getStatus() != ScheduleStatus.CANCELLED).toList();
        List<Attendance> attendance = attendanceRepository
                .findByScheduleStoreIdAndCheckInTimeBetweenOrderByCheckInTimeDesc(
                        store.getId(), from.atStartOfDay(), to.plusDays(1).atStartOfDay());
        long checkedOut = attendance.stream().filter(item -> item.getCheckOutTime() != null).count();
        long staffCount = userRepository.findByStoreId(store.getId()).stream()
                .filter(user -> user.getRole() == Role.STAFF).count();
        double attendanceRate = schedules.isEmpty() ? 0
                : Math.round((double) attendance.size() * 1000 / schedules.size()) / 10.0;

        Map<LocalDate, long[]> daily = new LinkedHashMap<>();
        for (LocalDate date = from; !date.isAfter(to); date = date.plusDays(1)) {
            daily.put(date, new long[2]);
        }
        for (UserSchedule schedule : schedules) {
            daily.get(schedule.getDate())[0]++;
        }
        for (Attendance record : attendance) {
            LocalDate date = record.getCheckInTime().toLocalDate();
            if (daily.containsKey(date)) {
                daily.get(date)[1]++;
            }
        }
        List<Map<String, Object>> dailyReport = daily.entrySet().stream().map(entry -> {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("date", entry.getKey());
            row.put("scheduled", entry.getValue()[0]);
            row.put("attended", entry.getValue()[1]);
            return row;
        }).toList();
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("from", from);
        response.put("to", to);
        response.put("staffCount", staffCount);
        response.put("scheduled", schedules.size());
        response.put("attended", attendance.size());
        response.put("checkedOut", checkedOut);
        response.put("openAttendance", attendance.size() - checkedOut);
        response.put("attendanceRate", attendanceRate);
        response.put("daily", dailyReport);
        return ResponseEntity.ok(ApiResponse.ok("Báo cáo chi nhánh", response));
    }

    @GetMapping("/requests")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getRequests(HttpServletRequest request) {
        Store store = getManagerStore(request);
        List<Map<String, Object>> items = branchRequestRepository
                .findByStoreIdOrderByCreatedAtDesc(store.getId())
                .stream().map(this::requestResponse).toList();
        return ResponseEntity.ok(ApiResponse.ok("Yêu cầu nhân viên", items));
    }

    @PutMapping("/requests/{id}")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> decideRequest(
            HttpServletRequest request,
            @PathVariable Long id,
            @Valid @RequestBody BranchRequestDecision body) {
        Store store = getManagerStore(request);
        return ResponseEntity.ok(ApiResponse.ok("Đã cập nhật trạng thái yêu cầu",
                staffRequestService.decide(store.getId(), id, body.getStatus(), body.getManagerNote())));
    }

    @PostMapping("/announcements")
    @Transactional
    public ResponseEntity<ApiResponse<Void>> announce(HttpServletRequest request, @Valid @RequestBody AnnouncementRequest body) {
        Store store = getManagerStore(request);
        userRepository.findByStoreId(store.getId()).stream().filter(u -> u.getRole() == Role.STAFF)
                .forEach(u -> staffNotifications.send(u, body.getTitle().trim(), body.getMessage().trim(), "ANNOUNCEMENT"));
        return ResponseEntity.ok(ApiResponse.ok("Đã gửi thông báo đến nhân viên chi nhánh", null));
    }

    private Store getManagerStore(HttpServletRequest request) {
        Object id = request.getAttribute("userId");
        if (!(id instanceof Long userId)) {
            throw new BusinessException("Không thể xác định tài khoản quản lý");
        }
        User manager = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException("Không tìm thấy tài khoản quản lý"));
        if (manager.getRole() != Role.MANAGER || manager.getStore() == null
                || manager.getEmploymentStatus() != com.cafehr.user.entity.EmploymentStatus.ACTIVE) {
            throw new BusinessException("Tài khoản chưa được gán vào chi nhánh quản lý");
        }
        boolean writing = org.springframework.transaction.support.TransactionSynchronizationManager.isActualTransactionActive();
        Store store = (writing ? storeRepository.findLockedById(manager.getStore().getId()) : storeRepository.findById(manager.getStore().getId()))
                .orElseThrow(() -> new BusinessException("Không tìm thấy chi nhánh"));
        if (writing) entityManager.refresh(store);
        if (store.getStatus() == StoreStatus.CLOSED) throw new BusinessException("Chi nhánh đã ngừng hoạt động");
        return store;
    }

    private User getStaffInStore(Long userId, Store store) {
        User user = userRepository.findLockedById(userId)
                .orElseThrow(() -> new BusinessException("Không tìm thấy nhân viên"));
        if (user.getRole() != Role.STAFF || user.getStore() == null || user.getEmploymentStatus() != com.cafehr.user.entity.EmploymentStatus.ACTIVE
                || !user.getStore().getId().equals(store.getId())) {
            throw new BusinessException("Nhân viên không thuộc chi nhánh của bạn");
        }
        return user;
    }

    private void validateRange(LocalDate from, LocalDate to) {
        if (from.isAfter(to) || from.plusMonths(3).isBefore(to)) {
            throw new BusinessException("Khoảng thời gian không hợp lệ (tối đa 3 tháng)");
        }
    }

    private Map<String, Object> staffResponse(User user) {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("id", user.getId());
        response.put("name", user.getName());
        response.put("phone", user.getPhone());
        response.put("role", user.getRole().name());
        response.put("deviceId", user.getDeviceId());
        response.put("storeId", user.getStore() != null ? user.getStore().getId() : null);
        response.put("storeName", user.getStore() != null ? user.getStore().getName() : null);
        response.put("fixedRoster", StaffViews.fixedRoster(user));
        return response;
    }

    private void applyFixedRoster(User staff, ManagerStaffRequest body) {
        if (body.getFixedRoster() == null) return;
        if (new java.util.HashSet<>(body.getFixedRoster()).size() != body.getFixedRoster().size()) {
            throw new BusinessException("Ca mặc định bị trùng thứ và ca làm");
        }
        staff.getFixedRoster().clear(); staff.getFixedRoster().addAll(body.getFixedRoster());
    }

    private Map<String, Object> scheduleResponse(UserSchedule schedule) {
        return StaffViews.schedule(schedule);
    }

    private Map<String, Object> attendanceResponse(Attendance attendance) {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("id", attendance.getId());
        response.put("userId", attendance.getUser().getId());
        response.put("userName", attendance.getUser().getName());
        response.put("shiftName", attendance.getSchedule().getShift().getName());
        response.put("checkInTime", attendance.getCheckInTime());
        response.put("checkOutTime", attendance.getCheckOutTime());
        response.put("status", attendance.getSchedule().getStatus().name());
        return response;
    }

    private Map<String, Object> requestResponse(BranchRequest branchRequest) {
        return StaffViews.request(branchRequest);
    }
}
