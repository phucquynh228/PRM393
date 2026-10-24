package com.cafehr.admin.controller;

import com.cafehr.admin.dto.DashboardSummaryResponse;
import com.cafehr.attendance.dto.AttendanceResponse;
import com.cafehr.attendance.repository.AttendanceRepository;
import com.cafehr.auth.repository.GoogleAccountRepository;
import com.cafehr.branch.dto.StoreRequest;
import com.cafehr.branch.dto.StoreResponse;
import com.cafehr.branch.entity.Store;
import com.cafehr.branch.entity.StoreStatus;
import com.cafehr.branch.repository.StoreRepository;
import com.cafehr.common.dto.ApiResponse;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.schedule.repository.ShiftRepository;
import com.cafehr.user.dto.UserAdminRequest;
import com.cafehr.user.dto.UserResponse;
import com.cafehr.user.entity.Role;
import com.cafehr.user.entity.User;
import com.cafehr.user.repository.UserRepository;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

/**
 * REST Controller dành cho Quản trị viên (Admin)
 * Đường dẫn: /api/admin/**
 */
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {

    private final StoreRepository storeRepository;
    private final UserRepository userRepository;
    private final ShiftRepository shiftRepository;
    private final AttendanceRepository attendanceRepository;
    private final PasswordEncoder passwordEncoder;
    private final GoogleAccountRepository googleAccounts;

    // ================= DASHBOARD BÁO CÁO =================
    @GetMapping("/dashboard")
    public ResponseEntity<ApiResponse<DashboardSummaryResponse>> getDashboardSummary() {
        DashboardSummaryResponse summary = DashboardSummaryResponse.builder()
                .totalStores(storeRepository.count())
                .totalUsers(userRepository.count())
                .totalShifts(shiftRepository.count())
                .todayAttendanceCount(attendanceRepository.count())
                .build();

        return ResponseEntity.ok(ApiResponse.ok("Báo cáo tổng hợp", summary));
    }

    // ================= QUẢN LÝ CHI NHÁNH (STORES) =================
    @GetMapping("/stores")
    public ResponseEntity<ApiResponse<List<StoreResponse>>> getAllStores() {
        List<StoreResponse> list = storeRepository.findAll().stream().map(this::toStoreResponse).collect(Collectors.toList());
        return ResponseEntity.ok(ApiResponse.ok("Danh sách chi nhánh", list));
    }

    @PostMapping("/stores")
    public ResponseEntity<ApiResponse<StoreResponse>> createStore(@Valid @RequestBody StoreRequest request) {
        // 1. Chuẩn hóa & kiểm tra trùng mã chi nhánh
        String code = normalizeCode(request.getCode(), request.getName());
        if (storeRepository.existsByCode(code)) {
            throw new BusinessException("Mã chi nhánh '" + code + "' đã tồn tại trong hệ thống. Vui lòng nhập mã khác.");
        }

        // 2. Parse trạng thái hoạt động
        StoreStatus status = parseStatus(request.getStatus());

        // 3. Build Store Entity
        Store store = Store.builder()
                .code(code)
                .name(request.getName().trim())
                .latitude(request.getLatitude())
                .longitude(request.getLongitude())
                .allowedRadius(request.getAllowedRadius() != null ? request.getAllowedRadius() : 200)
                .maxStaff(request.getMaxStaff() != null && request.getMaxStaff() > 0 ? request.getMaxStaff() : 15)
                .status(status)
                .build();

        // 4. Bổ nhiệm Cửa hàng trưởng (nếu có)
        if (request.getManagerId() != null) {
            User manager = userRepository.findById(request.getManagerId())
                    .orElseThrow(() -> new BusinessException("Không tìm thấy Cửa hàng trưởng với id: " + request.getManagerId()));
            manager.setRole(Role.MANAGER);
            manager.setStore(store);
            userRepository.save(manager);
            store.setManager(manager);
        }

        Store savedStore = storeRepository.save(store);
        return ResponseEntity.ok(ApiResponse.ok("Tạo chi nhánh thành công", toStoreResponse(savedStore)));
    }

    @PutMapping("/stores/{id}")
    public ResponseEntity<ApiResponse<StoreResponse>> updateStore(@PathVariable Long id, @Valid @RequestBody StoreRequest request) {
        Store store = storeRepository.findById(id)
                .orElseThrow(() -> new BusinessException("Không tìm thấy chi nhánh id: " + id));

        // 1. Kiểm tra trùng mã nếu đổi mã mới
        if (request.getCode() != null && !request.getCode().isBlank()) {
            String newCode = request.getCode().trim().toUpperCase();
            if (storeRepository.existsByCodeAndIdNot(newCode, id)) {
                throw new BusinessException("Mã chi nhánh '" + newCode + "' đã tồn tại. Vui lòng chọn mã khác.");
            }
            store.setCode(newCode);
        }

        // 2. Kiểm tra RÀNG BUỘC ĐÓNG CỬA (CLOSED)
        StoreStatus newStatus = parseStatus(request.getStatus());
        long currentStaffCount = userRepository.findByStoreId(id).size();

        if (newStatus == StoreStatus.CLOSED && currentStaffCount > 0) {
            throw new BusinessException("Không thể chuyển chi nhánh '" + store.getName() +
                    "' sang trạng thái CLOSED (Ngừng hoạt động) vì vẫn còn " + currentStaffCount +
                    " nhân viên đang trực thuộc. Vui lòng điều chuyển hết nhân viên sang cơ sở khác trước khi đóng cửa.");
        }

        // 3. Kiểm tra RÀNG BUỘC ĐỊNH BIÊN (Max Staff)
        if (request.getMaxStaff() != null && request.getMaxStaff() < currentStaffCount) {
            throw new BusinessException("Định biên mới (" + request.getMaxStaff() +
                    " người) nhỏ hơn số lượng nhân viên hiện tại (" + currentStaffCount +
                    " người). Vui lòng điều chuyển bớt nhân viên trước khi hạ định biên.");
        }

        if (request.getName() != null && !request.getName().isBlank()) store.setName(request.getName().trim());
        if (request.getLatitude() != null) store.setLatitude(request.getLatitude());
        if (request.getLongitude() != null) store.setLongitude(request.getLongitude());
        if (request.getAllowedRadius() != null) store.setAllowedRadius(request.getAllowedRadius());
        if (request.getMaxStaff() != null && request.getMaxStaff() > 0) store.setMaxStaff(request.getMaxStaff());
        store.setStatus(newStatus);

        // 4. Bổ nhiệm Cửa hàng trưởng (Manager Assignment / Succession)
        if (request.getManagerId() != null) {
            User newManager = userRepository.findById(request.getManagerId())
                    .orElseThrow(() -> new BusinessException("Không tìm thấy user id: " + request.getManagerId()));

            User oldManager = store.getManager();
            if (oldManager != null && !oldManager.getId().equals(newManager.getId())) {
                // Giáng cấp Cửa hàng trưởng cũ xuống STAFF
                oldManager.setRole(Role.STAFF);
                userRepository.save(oldManager);
            }

            newManager.setRole(Role.MANAGER);
            newManager.setStore(store);
            userRepository.save(newManager);
            store.setManager(newManager);
        }

        Store updatedStore = storeRepository.save(store);
        return ResponseEntity.ok(ApiResponse.ok("Cập nhật chi nhánh thành công", toStoreResponse(updatedStore)));
    }

    @DeleteMapping("/stores/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteStore(@PathVariable Long id) {
        Store store = storeRepository.findById(id)
                .orElseThrow(() -> new BusinessException("Không tìm thấy chi nhánh id: " + id));

        long currentStaffCount = userRepository.findByStoreId(id).size();
        if (currentStaffCount > 0) {
            throw new BusinessException("Không thể xóa chi nhánh '" + store.getName() +
                    "' vì còn " + currentStaffCount + " nhân viên thuộc cơ sở này. Vui lòng điều chuyển nhân viên trước.");
        }

        storeRepository.deleteById(id);
        return ResponseEntity.ok(ApiResponse.ok("Xóa chi nhánh thành công", null));
    }

    // ================= QUẢN LÝ TÀI KHOẢN & PHÂN QUYỀN (USERS) =================
    @GetMapping("/users")
    public ResponseEntity<ApiResponse<List<UserResponse>>> getAllUsers() {
        List<UserResponse> users = userRepository.findAll().stream().map(this::toUserResponse).collect(Collectors.toList());
        return ResponseEntity.ok(ApiResponse.ok("Danh sách tài khoản", users));
    }

    @PostMapping("/users")
    public ResponseEntity<ApiResponse<UserResponse>> createUser(@Valid @RequestBody UserAdminRequest request) {
        if (userRepository.existsByPhone(request.getPhone())) {
            throw new BusinessException("Số điện thoại đã tồn tại trong hệ thống");
        }

        Store store = null;
        if (request.getStoreId() != null) {
            store = storeRepository.findById(request.getStoreId())
                    .orElseThrow(() -> new BusinessException("Không tìm thấy chi nhánh id: " + request.getStoreId()));

            // Validate Store Status & Max Staff
            validateStoreForUserAssignment(store, null);
        }

        String rawPassword = (request.getPassword() != null && !request.getPassword().isBlank())
                ? request.getPassword()
                : "123456";

        Role role = parseRole(request.getRole());

        User user = User.builder()
                .name(request.getName().trim())
                .phone(request.getPhone().trim())
                .password(passwordEncoder.encode(rawPassword))
                .role(role)
                .store(store)
                .build();

        User savedUser = userRepository.save(user);

        // If assigned as MANAGER, update Store's manager
        if (role == Role.MANAGER && store != null) {
            store.setManager(savedUser);
            storeRepository.save(store);
        }

        return ResponseEntity.ok(ApiResponse.ok("Tạo tài khoản thành công", toUserResponse(savedUser)));
    }

    @PutMapping("/users/{id}")
    public ResponseEntity<ApiResponse<UserResponse>> updateUser(@PathVariable Long id, @RequestBody UserAdminRequest request) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new BusinessException("Không tìm thấy tài khoản id: " + id));

        if (request.getName() != null && !request.getName().isBlank()) {
            user.setName(request.getName().trim());
        }

        if (request.getPhone() != null && !request.getPhone().isBlank() && !user.getPhone().equals(request.getPhone())) {
            if (userRepository.existsByPhone(request.getPhone())) {
                throw new BusinessException("Số điện thoại đã tồn tại trong hệ thống");
            }
            user.setPhone(request.getPhone().trim());
        }

        if (request.getPassword() != null && !request.getPassword().isBlank()) {
            user.setPassword(passwordEncoder.encode(request.getPassword()));
        }

        if (request.getRole() != null) {
            user.setRole(parseRole(request.getRole()));
        }

        // Cập nhật/Điều động Chi nhánh
        if (request.getStoreId() != null) {
            Store newStore = storeRepository.findById(request.getStoreId())
                    .orElseThrow(() -> new BusinessException("Không tìm thấy chi nhánh id: " + request.getStoreId()));

            // Nếu điều chuyển sang chi nhánh khác -> kiểm tra định biên & trạng thái chi nhánh mới
            if (user.getStore() == null || !user.getStore().getId().equals(newStore.getId())) {
                validateStoreForUserAssignment(newStore, user.getId());
            }
            user.setStore(newStore);
        }

        User updatedUser = userRepository.save(user);
        return ResponseEntity.ok(ApiResponse.ok("Cập nhật tài khoản thành công", toUserResponse(updatedUser)));
    }

    @DeleteMapping("/users/{id}")
    @org.springframework.transaction.annotation.Transactional
    public ResponseEntity<ApiResponse<Void>> deleteUser(@PathVariable Long id) {
        if (!userRepository.existsById(id)) {
            throw new BusinessException("Không tìm thấy tài khoản id: " + id);
        }
        googleAccounts.findByUserId(id).ifPresent(googleAccounts::delete);
        googleAccounts.flush();
        userRepository.deleteById(id);
        return ResponseEntity.ok(ApiResponse.ok("Xóa tài khoản thành công", null));
    }

    // ================= XEM CHẤM CÔNG TOÀN CHUỖI =================
    @GetMapping("/attendance")
    public ResponseEntity<ApiResponse<List<AttendanceResponse>>> getAllAttendance() {
        List<AttendanceResponse> list = attendanceRepository.findAll().stream().map(a -> AttendanceResponse.builder()
                .id(a.getId())
                .userId(a.getUser().getId())
                .userName(a.getUser().getName())
                .scheduleId(a.getSchedule() != null ? a.getSchedule().getId() : null)
                .shiftName(a.getSchedule() != null && a.getSchedule().getShift() != null ? a.getSchedule().getShift().getName() : "N/A")
                .checkInTime(a.getCheckInTime())
                .checkOutTime(a.getCheckOutTime())
                .checkInLat(a.getCheckInLat())
                .checkInLng(a.getCheckInLng())
                .status(a.getSchedule() != null && a.getSchedule().getStatus() != null ? a.getSchedule().getStatus().name() : "N/A")
                .build()
        ).collect(Collectors.toList());

        return ResponseEntity.ok(ApiResponse.ok("Danh sách chấm công toàn chuỗi", list));
    }

    // ================= HELPERS & MAPPERS =================
    private void validateStoreForUserAssignment(Store store, Long userId) {
        if (store.getStatus() == StoreStatus.CLOSED) {
            throw new BusinessException("Chi nhánh '" + store.getName() + "' đang ở trạng thái CLOSED (Ngừng hoạt động). Không thể tiếp nhận nhân viên mới.");
        }

        long currentCount = userRepository.findByStoreId(store.getId()).stream()
                .filter(u -> userId == null || !u.getId().equals(userId))
                .count();

        if (currentCount >= store.getMaxStaff()) {
            throw new BusinessException("Cảnh báo định biên: Chi nhánh '" + store.getName() +
                    "' đã đạt số lượng nhân sự tối đa (" + currentCount + "/" + store.getMaxStaff() + " người). Không thể gán thêm.");
        }
    }

    private String normalizeCode(String inputCode, String storeName) {
        if (inputCode != null && !inputCode.isBlank()) {
            return inputCode.trim().toUpperCase();
        }
        // Tự động tạo mã nếu bỏ trống: VD "Cafe Thủ Đức" -> "TD-01"
        long count = storeRepository.count() + 1;
        return "CN-" + String.format("%02d", count);
    }

    private StoreStatus parseStatus(String inputStatus) {
        if (inputStatus == null || inputStatus.isBlank()) return StoreStatus.ACTIVE;
        try {
            return StoreStatus.valueOf(inputStatus.trim().toUpperCase());
        } catch (Exception e) {
            return StoreStatus.ACTIVE;
        }
    }

    private Role parseRole(String inputRole) {
        if (inputRole == null || inputRole.isBlank()) return Role.STAFF;
        try {
            return Role.valueOf(inputRole.trim().toUpperCase());
        } catch (Exception e) {
            return Role.STAFF;
        }
    }

    private StoreResponse toStoreResponse(Store store) {
        long currentCount = userRepository.findByStoreId(store.getId()).size();
        return StoreResponse.builder()
                .id(store.getId())
                .code(store.getCode())
                .name(store.getName())
                .latitude(store.getLatitude())
                .longitude(store.getLongitude())
                .allowedRadius(store.getAllowedRadius())
                .maxStaff(store.getMaxStaff())
                .status(store.getStatus().name())
                .managerId(store.getManager() != null ? store.getManager().getId() : null)
                .managerName(store.getManager() != null ? store.getManager().getName() : "Chưa bổ nhiệm")
                .managerPhone(store.getManager() != null ? store.getManager().getPhone() : null)
                .currentStaffCount(currentCount)
                .build();
    }

    private UserResponse toUserResponse(User user) {
        return UserResponse.builder()
                .id(user.getId())
                .name(user.getName())
                .phone(user.getPhone())
                .role(user.getRole().name())
                .storeId(user.getStore() != null ? user.getStore().getId() : null)
                .storeName(user.getStore() != null ? user.getStore().getName() : "Chưa phân chi nhánh")
                .deviceId(user.getDeviceId())
                .build();
    }
}
