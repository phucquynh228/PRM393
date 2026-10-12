package com.cafehr.controller;

import com.cafehr.dto.*;
import com.cafehr.entity.*;
import com.cafehr.exception.BusinessException;
import com.cafehr.repository.*;
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
    public ResponseEntity<ApiResponse<List<Store>>> getAllStores() {
        return ResponseEntity.ok(ApiResponse.ok("Danh sách chi nhánh", storeRepository.findAll()));
    }

    @PostMapping("/stores")
    public ResponseEntity<ApiResponse<Store>> createStore(@Valid @RequestBody StoreRequest request) {
        Store store = Store.builder()
                .name(request.getName())
                .latitude(request.getLatitude())
                .longitude(request.getLongitude())
                .allowedRadius(request.getAllowedRadius())
                .build();

        Store savedStore = storeRepository.save(store);
        return ResponseEntity.ok(ApiResponse.ok("Tạo chi nhánh thành công", savedStore));
    }

    @PutMapping("/stores/{id}")
    public ResponseEntity<ApiResponse<Store>> updateStore(@PathVariable Long id, @Valid @RequestBody StoreRequest request) {
        Store store = storeRepository.findById(id)
                .orElseThrow(() -> new BusinessException("Không tìm thấy chi nhánh id: " + id));

        store.setName(request.getName());
        store.setLatitude(request.getLatitude());
        store.setLongitude(request.getLongitude());
        store.setAllowedRadius(request.getAllowedRadius());

        Store updatedStore = storeRepository.save(store);
        return ResponseEntity.ok(ApiResponse.ok("Cập nhật chi nhánh thành công", updatedStore));
    }

    @DeleteMapping("/stores/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteStore(@PathVariable Long id) {
        if (!storeRepository.existsById(id)) {
            throw new BusinessException("Không tìm thấy chi nhánh id: " + id);
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

        String rawPassword = (request.getPassword() != null && !request.getPassword().isBlank())
                ? request.getPassword()
                : "123456";

        Store store = null;
        if (request.getStoreId() != null) {
            store = storeRepository.findById(request.getStoreId()).orElse(null);
        }

        Role role;
        try {
            role = Role.valueOf(request.getRole().toUpperCase());
        } catch (Exception e) {
            role = Role.STAFF;
        }

        User user = User.builder()
                .name(request.getName())
                .phone(request.getPhone())
                .password(passwordEncoder.encode(rawPassword))
                .role(role)
                .store(store)
                .build();

        User savedUser = userRepository.save(user);
        return ResponseEntity.ok(ApiResponse.ok("Tạo tài khoản thành công", toUserResponse(savedUser)));
    }

    @PutMapping("/users/{id}")
    public ResponseEntity<ApiResponse<UserResponse>> updateUser(@PathVariable Long id, @RequestBody UserAdminRequest request) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new BusinessException("Không tìm thấy tài khoản id: " + id));

        if (request.getName() != null && !request.getName().isBlank()) {
            user.setName(request.getName());
        }

        if (request.getPhone() != null && !request.getPhone().isBlank() && !user.getPhone().equals(request.getPhone())) {
            if (userRepository.existsByPhone(request.getPhone())) {
                throw new BusinessException("Số điện thoại đã tồn tại");
            }
            user.setPhone(request.getPhone());
        }

        if (request.getPassword() != null && !request.getPassword().isBlank()) {
            user.setPassword(passwordEncoder.encode(request.getPassword()));
        }

        if (request.getRole() != null) {
            try {
                user.setRole(Role.valueOf(request.getRole().toUpperCase()));
            } catch (Exception ignored) {}
        }

        if (request.getStoreId() != null) {
            Store store = storeRepository.findById(request.getStoreId()).orElse(null);
            user.setStore(store);
        }

        User updatedUser = userRepository.save(user);
        return ResponseEntity.ok(ApiResponse.ok("Cập nhật tài khoản thành công", toUserResponse(updatedUser)));
    }

    @DeleteMapping("/users/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteUser(@PathVariable Long id) {
        if (!userRepository.existsById(id)) {
            throw new BusinessException("Không tìm thấy tài khoản id: " + id);
        }
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
