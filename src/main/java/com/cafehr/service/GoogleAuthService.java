package com.cafehr.service;

import com.cafehr.dto.*;
import com.cafehr.entity.GoogleAccount;
import com.cafehr.entity.User;
import com.cafehr.exception.BusinessException;
import com.cafehr.repository.GoogleAccountRepository;
import com.cafehr.repository.UserRepository;
import com.cafehr.security.GoogleTokenVerifier;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service @RequiredArgsConstructor
public class GoogleAuthService {
    private final GoogleTokenVerifier verifier;
    private final GoogleAccountRepository accounts;
    private final UserRepository users;
    private final AuthenticationManager authenticationManager;
    private final AuthService auth;

    public java.util.Map<String, Object> configuration() {
        boolean enabled = verifier.isConfigured();
        return java.util.Map.of("enabled", enabled, "clientId", enabled ? verifier.clientId() : "");
    }

    @Transactional
    public GoogleLoginResponse login(GoogleLoginRequest request) {
        GoogleTokenVerifier.Identity identity = verifier.verify(request.getIdToken());
        GoogleAccount account = accounts.findBySubject(identity.subject()).orElse(null);
        if (account == null) return new GoogleLoginResponse(true, identity.email(), null);
        account.setEmail(identity.email());
        return new GoogleLoginResponse(false, identity.email(), auth.createSession(account.getUser(), request.getDeviceId()));
    }

    @Transactional
    public LoginResponse link(GoogleLinkRequest request) {
        GoogleTokenVerifier.Identity identity = verifier.verify(request.getIdToken());
        String phone = request.getPhone().trim();
        authenticationManager.authenticate(new UsernamePasswordAuthenticationToken(phone, request.getPassword()));
        User candidate = users.findByPhone(phone).orElseThrow(() -> new BusinessException("Không tìm thấy tài khoản HRM"));
        User user = users.findLockedById(candidate.getId()).orElseThrow(() -> new BusinessException("Không tìm thấy tài khoản HRM"));
        GoogleAccount subjectAccount = accounts.findBySubject(identity.subject()).orElse(null);
        if (subjectAccount != null && !subjectAccount.getUser().getId().equals(user.getId())) {
            throw new BusinessException("Tài khoản Google này đã liên kết với một tài khoản HRM khác.");
        }
        GoogleAccount userAccount = accounts.findByUserId(user.getId()).orElse(null);
        if (userAccount != null && !userAccount.getSubject().equals(identity.subject())) {
            throw new BusinessException("Tài khoản HRM đã liên kết với Google khác. Vui lòng dùng tài khoản Google đã liên kết.");
        }
        if (subjectAccount == null && userAccount == null) {
            try {
                accounts.saveAndFlush(GoogleAccount.builder().subject(identity.subject()).email(identity.email()).user(user).build());
            } catch (org.springframework.dao.DataIntegrityViolationException e) {
                throw new BusinessException("Liên kết Google đã thay đổi. Vui lòng đăng nhập lại.");
            }
        }
        // No account creation, role changes, or automatic linking by a profile email.
        return auth.createSession(user, request.getDeviceId());
    }
}
