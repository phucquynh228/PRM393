package com.cafehr.admin.controller;

import com.cafehr.auth.repository.GoogleAccountRepository;
import com.cafehr.common.dto.ApiResponse;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.system.entity.SystemConfig;
import com.cafehr.system.repository.SystemConfigRepository;
import com.cafehr.user.entity.User;
import com.cafehr.user.repository.UserRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import static com.cafehr.staff.view.StaffViews.row;

@RestController @RequestMapping("/api/admin") @RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')") @Transactional
public class AdminProfileController {
    private final UserRepository users;
    private final GoogleAccountRepository google;
    private final PasswordEncoder passwords;
    private final SystemConfigRepository settings;

    public record ProfileUpdate(@NotBlank @Size(max=100) String name,
            @Email @Size(max=150) String email, @Size(max=255) String address) {}
    // No generated toString: credentials must never appear in request logs.
    public static class PasswordUpdate {
        @NotBlank public String currentPassword;
        @NotBlank @Size(min=8, max=72) public String newPassword;
    }
    public record SettingsUpdate(@Min(1) @Max(120) int reminderMinutes) {}

    private User current(Authentication auth, boolean locked) {
        var user = users.findByPhone(auth.getName()).orElseThrow(() -> new BusinessException("Không tìm thấy tài khoản"));
        return locked ? users.findLockedById(user.getId()).orElseThrow() : user;
    }
    private Map<String,Object> view(User user) {
        return row("id", user.getId(), "name", user.getName(), "phone", user.getPhone(), "email", user.getEmail(),
                "address", user.getAddress(), "role", user.getRole().name(), "deviceLinked", user.getDeviceId() != null,
                "googleLinked", google.findByUserId(user.getId()).isPresent());
    }
    @GetMapping("/profile") @Transactional(readOnly=true)
    public ApiResponse<Map<String,Object>> profile(Authentication auth) { return ApiResponse.ok(view(current(auth, false))); }

    @PutMapping("/profile")
    public ApiResponse<Map<String,Object>> update(Authentication auth, @Valid @RequestBody ProfileUpdate body) {
        var user = current(auth, true);
        user.setName(body.name().trim()); user.setEmail(body.email() == null ? null : body.email().trim());
        user.setAddress(body.address() == null ? null : body.address().trim());
        return ApiResponse.ok("Đã cập nhật thông tin cá nhân", view(user));
    }
    @PutMapping("/profile/password")
    public ApiResponse<Void> password(Authentication auth, @Valid @RequestBody PasswordUpdate body) {
        var user = current(auth, true);
        if (!passwords.matches(body.currentPassword, user.getPassword())) throw new BusinessException("Mật khẩu hiện tại không đúng");
        if (body.newPassword.isBlank() || body.newPassword.getBytes(StandardCharsets.UTF_8).length > 72)
            throw new BusinessException("Mật khẩu tối đa 72 byte UTF-8");
        if (passwords.matches(body.newPassword, user.getPassword())) throw new BusinessException("Mật khẩu mới phải khác mật khẩu hiện tại");
        user.setPassword(passwords.encode(body.newPassword)); user.setCredentialsVersion(user.getCredentialsVersion() + 1);
        return ApiResponse.ok("Đã đổi mật khẩu. Vui lòng đăng nhập lại.", null);
    }
    @GetMapping("/settings") @Transactional(readOnly=true)
    public ApiResponse<Map<String,Object>> settings() {
        int minutes = settings.findByConfigKey("reminder_minutes").map(s -> {
            try { return Integer.parseInt(s.getConfigValue()); } catch (NumberFormatException ex) { return 10; }
        }).orElse(10);
        return ApiResponse.ok(row("reminderMinutes", minutes, "timezone", "Asia/Ho_Chi_Minh", "maxCheckoutHours",
                com.cafehr.attendance.service.AttendanceTiming.MAX_DURATION.toHours()));
    }
    @PutMapping("/settings")
    public ApiResponse<Map<String,Object>> saveSettings(@Valid @RequestBody SettingsUpdate body) {
        var config = settings.findByConfigKey("reminder_minutes").orElseGet(() -> SystemConfig.builder().configKey("reminder_minutes").build());
        config.setConfigValue(Integer.toString(body.reminderMinutes())); settings.save(config);
        return settings();
    }
}
