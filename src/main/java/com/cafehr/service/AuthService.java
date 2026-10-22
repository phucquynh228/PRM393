package com.cafehr.service;

import com.cafehr.dto.LoginRequest;
import com.cafehr.dto.LoginResponse;
import com.cafehr.entity.User;
import com.cafehr.exception.DeviceNotMatchException;
import com.cafehr.repository.UserRepository;
import com.cafehr.security.JwtUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Service xử lý Authentication và Device Binding Logic.
 *
 * Flow login:
 * 1. Authenticate phone + password qua Spring Security AuthenticationManager.
 * 2. Kiểm tra Device Binding:
 *    - Nếu user chưa có deviceId -> Bind deviceId mới, tạo JWT.
 *    - Nếu đã có deviceId -> So sánh với deviceId gửi lên:
 *        + Khớp -> Tạo JWT.
 *        + Không khớp -> Ném DeviceNotMatchException (HTTP 403).
 * 3. Trả về LoginResponse chứa JWT và thông tin user.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final UserRepository userRepository;
    private final JwtUtil jwtUtil;
    private final AuthenticationManager authenticationManager;
    private final PasswordEncoder passwordEncoder;

    /**
     * Xử lý đăng nhập với Device Binding.
     */
    @Transactional
    public LoginResponse login(LoginRequest request) {
        // Bước 1: Xác thực phone + password
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                        request.getPhone(),
                        request.getPassword()
                )
        );

        // Bước 2: Lấy user từ DB
        User user = userRepository.findByPhone(request.getPhone())
                .orElseThrow(() -> new RuntimeException("User không tồn tại"));

        return createSession(user, request.getDeviceId());
    }

    /** Shared session behavior for verified phone/password and Google identities. */
    @Transactional
    public LoginResponse createSession(User user, String incomingDeviceId) {

        if (user.getDeviceId() == null || user.getDeviceId().isBlank()) {
            // Lần đầu đăng nhập -> Bind thiết bị
            user.setDeviceId(incomingDeviceId);
            userRepository.save(user);
            log.info("Device bound cho user [{}]: deviceId={}", user.getPhone(), incomingDeviceId);
        } else if (!user.getDeviceId().equals(incomingDeviceId)) {
            // Cập nhật thiết bị mới cho user
            log.info("Cập nhật thiết bị mới cho user [{}]: old={}, new={}",
                    user.getPhone(), user.getDeviceId(), incomingDeviceId);
            user.setDeviceId(incomingDeviceId);
            userRepository.save(user);
        }

        // Bước 4: Tạo JWT token
        String token = jwtUtil.generateToken(
                user.getPhone(),
                user.getId(),
                user.getRole().name()
        );

        // Bước 5: Build response
        return LoginResponse.builder()
                .token(token)
                .tokenType("Bearer")
                .userId(user.getId())
                .name(user.getName())
                .phone(user.getPhone())
                .role(user.getRole().name())
                .storeId(user.getStore() != null ? user.getStore().getId() : null)
                .build();
    }

    /**
     * Reset device binding (dành cho ADMIN/MANAGER).
     * Cho phép user đăng nhập lại trên thiết bị mới.
     */
    @Transactional
    public void resetDevice(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User không tồn tại với id: " + userId));

        user.setDeviceId(null);
        userRepository.save(user);
        log.info("Device reset cho user [{}] (id={})", user.getPhone(), userId);
    }
}
