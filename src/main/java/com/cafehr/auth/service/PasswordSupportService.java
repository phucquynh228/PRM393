package com.cafehr.auth.service;

import com.cafehr.auth.dto.*;
import com.cafehr.auth.entity.PasswordSupportRequest;
import com.cafehr.auth.entity.PasswordSupportRequest.Status;
import com.cafehr.auth.repository.PasswordSupportRepository;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.user.entity.*;
import com.cafehr.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.List;

@Service @RequiredArgsConstructor
public class PasswordSupportService {
    public static final String ACKNOWLEDGEMENT = "Nếu thông tin khớp với tài khoản nhân viên hoặc quản lý, yêu cầu sẽ được chuyển đến Admin. Vui lòng gặp trực tiếp Admin để xác minh và nhận hỗ trợ.";
    private final UserRepository users;
    private final PasswordSupportRepository requests;
    private final PasswordEncoder passwords;

    @Transactional
    public void submit(PasswordSupportSubmission body) {
        User found = users.findByPhone(body.phone()).orElse(null);
        if (found == null) return;
        User user = users.findLockedById(found.getId()).orElse(null);
        if (user == null || user.getRole() == Role.ADMIN) return;
        var latest = requests.findFirstByUserIdOrderByCreatedAtDesc(user.getId()).orElse(null);
        // Keep the original unverified report; repeated anonymous submissions must not overwrite it.
        if (latest != null && (latest.getStatus() == Status.PENDING
                || latest.getCreatedAt().isAfter(LocalDateTime.now().minusMinutes(5)))) return;
        var request = new PasswordSupportRequest();
        request.setUser(user);
        request.setRequestedName(body.name().trim());
        request.setNote(clean(body.note()));
        requests.save(request);
    }

    @Transactional(readOnly = true)
    public List<PasswordSupportView> list(Status status) {
        return requests.findTop100ByStatusOrderByCreatedAtDesc(status).stream().map(this::view).toList();
    }

    @Transactional
    public PasswordSupportView decide(Long id, String adminPhone, PasswordSupportDecision body) {
        User admin = users.findByPhone(adminPhone)
                .filter(u -> u.getRole() == Role.ADMIN && u.getEmploymentStatus() != EmploymentStatus.INACTIVE)
                .orElseThrow(() -> new AccessDeniedException("Chỉ Admin được xử lý yêu cầu"));
        var found = requests.findById(id).orElseThrow(() -> new BusinessException("Không tìm thấy yêu cầu"));
        User user = users.findLockedById(found.getUser().getId())
                .orElseThrow(() -> new BusinessException("Không tìm thấy tài khoản"));
        var request = requests.findLockedById(id).orElseThrow(() -> new BusinessException("Không tìm thấy yêu cầu"));
        if (request.getStatus() != Status.PENDING) throw new BusinessException("Yêu cầu đã được xử lý. Vui lòng làm mới danh sách.");
        if ("RESOLVE".equals(body.getAction())) {
            if (!body.isIdentityVerified()) throw new BusinessException("Cần xác minh trực tiếp danh tính nhân viên trước khi đặt lại mật khẩu");
            if (user.getRole() == Role.ADMIN || user.getEmploymentStatus() == EmploymentStatus.INACTIVE)
                throw new BusinessException("Không thể đặt lại mật khẩu cho tài khoản này qua yêu cầu hỗ trợ");
            String password = body.getNewPassword();
            if (password == null || password.isBlank() || password.length() < 8
                    || password.getBytes(StandardCharsets.UTF_8).length > 72)
                throw new BusinessException("Mật khẩu mới cần ít nhất 8 ký tự và tối đa 72 byte UTF-8");
            if (passwords.matches(password, user.getPassword())) throw new BusinessException("Mật khẩu mới phải khác mật khẩu hiện tại");
            user.setPassword(passwords.encode(password));
            user.setCredentialsVersion(user.getCredentialsVersion() + 1);
            users.save(user);
            request.setStatus(Status.RESOLVED);
        } else if ("REJECT".equals(body.getAction())) {
            if (clean(body.getAdminNote()) == null) throw new BusinessException("Vui lòng nhập lý do từ chối");
            request.setStatus(Status.REJECTED);
        } else {
            throw new BusinessException("Thao tác không hợp lệ");
        }
        request.setHandledAt(LocalDateTime.now());
        request.setHandledBy(admin);
        request.setAdminNote(clean(body.getAdminNote()));
        requests.save(request);
        return view(request);
    }

    private PasswordSupportView view(PasswordSupportRequest r) {
        User u = r.getUser();
        return new PasswordSupportView(r.getId(), u.getId(), u.getName(), u.getPhone(), u.getRole().name(),
                u.getStore() == null ? null : u.getStore().getName(), r.getRequestedName(), r.getNote(),
                r.getStatus().name(), r.getCreatedAt(), r.getHandledAt(),
                r.getHandledBy() == null ? null : r.getHandledBy().getName(), r.getAdminNote());
    }

    private String clean(String value) { return value == null || value.isBlank() ? null : value.trim(); }
}
