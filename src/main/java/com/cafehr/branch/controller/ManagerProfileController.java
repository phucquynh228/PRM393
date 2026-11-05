package com.cafehr.branch.controller;

import com.cafehr.common.dto.ApiResponse;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.staff.dto.PasswordChangeRequest;
import com.cafehr.staff.dto.StaffProfileUpdate;
import com.cafehr.staff.view.StaffViews;
import com.cafehr.user.entity.Role;
import com.cafehr.user.entity.User;
import com.cafehr.user.repository.UserRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.util.Map;

@RestController
@RequestMapping("/api/manager")
@RequiredArgsConstructor
@PreAuthorize("hasRole('MANAGER')")
@Transactional
public class ManagerProfileController {
    private final UserRepository users;
    private final PasswordEncoder passwords;

    private User current(Authentication auth, boolean locked) {
        User user = users.findByPhone(auth.getName()).filter(u -> u.getRole() == Role.MANAGER)
                .orElseThrow(() -> new BusinessException("Không tìm thấy tài khoản quản lý"));
        return locked ? users.findLockedById(user.getId()).orElseThrow() : user;
    }

    @GetMapping("/profile")
    @Transactional(readOnly = true)
    public ApiResponse<Map<String, Object>> profile(Authentication auth) {
        return ApiResponse.ok(StaffViews.profile(current(auth, false)));
    }

    @PutMapping("/profile")
    public ApiResponse<Map<String, Object>> update(Authentication auth, @Valid @RequestBody StaffProfileUpdate body) {
        User user = current(auth, true);
        user.setName(body.getName().trim());
        user.setEmail(clean(body.getEmail()));
        user.setAddress(clean(body.getAddress()));
        user.setEmergencyContact(clean(body.getEmergencyContact()));
        return ApiResponse.ok("Đã cập nhật hồ sơ", StaffViews.profile(user));
    }

    @PutMapping("/password")
    public ApiResponse<Void> password(Authentication auth, @Valid @RequestBody PasswordChangeRequest body) {
        User user = current(auth, true);
        if (!passwords.matches(body.getCurrentPassword(), user.getPassword()))
            throw new BusinessException("Mật khẩu hiện tại không đúng");
        if (passwords.matches(body.getNewPassword(), user.getPassword()))
            throw new BusinessException("Mật khẩu mới phải khác mật khẩu hiện tại");
        if (body.getNewPassword().getBytes(StandardCharsets.UTF_8).length > 72)
            throw new BusinessException("Mật khẩu tối đa 72 byte UTF-8");
        user.setPassword(passwords.encode(body.getNewPassword()));
        return ApiResponse.ok("Đã đổi mật khẩu", null);
    }

    private String clean(String value) { return value == null || value.isBlank() ? null : value.trim(); }
}
