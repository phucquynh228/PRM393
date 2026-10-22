package com.cafehr.security;

import com.cafehr.exception.GoogleAuthenticationException;
import com.cafehr.exception.GoogleUnavailableException;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.List;

/** Checks Google's signature, issuer, expiry and this app's exact audience. */
@Component
public class GoogleTokenVerifier {
    public record Identity(String subject, String email) {}
    private final String clientId;
    private final GoogleIdTokenVerifier verifier;

    @org.springframework.beans.factory.annotation.Autowired
    public GoogleTokenVerifier(@Value("${google.auth.client-id:}") String clientId) {
        this(clientId.trim(), new GoogleIdTokenVerifier.Builder(new NetHttpTransport(), GsonFactory.getDefaultInstance())
                .setAudience(List.of(clientId.trim())).build());
    }

    GoogleTokenVerifier(String clientId, GoogleIdTokenVerifier verifier) {
        this.clientId = clientId;
        this.verifier = verifier;
    }

    public Identity verify(String rawToken) {
        if (!isConfigured()) {
            throw new GoogleUnavailableException("Đăng nhập Google chưa được cấu hình. Vui lòng đăng nhập bằng số điện thoại.");
        }
        GoogleIdToken parsed;
        try {
            parsed = GoogleIdToken.parse(GsonFactory.getDefaultInstance(), rawToken);
        } catch (IOException | IllegalArgumentException e) {
            throw invalid();
        }
        try {
            GoogleIdToken token = verifier.verify(parsed) ? parsed : null;
            if (token == null || !Boolean.TRUE.equals(token.getPayload().getEmailVerified())
                    || token.getPayload().getSubject() == null || token.getPayload().getSubject().isBlank()
                    || token.getPayload().getEmail() == null || token.getPayload().getEmail().isBlank()) {
                throw invalid();
            }
            return new Identity(token.getPayload().getSubject(), token.getPayload().getEmail());
        } catch (GeneralSecurityException | IllegalArgumentException e) {
            throw invalid();
        } catch (IOException e) {
            throw new GoogleUnavailableException("Chưa xác minh được tài khoản với Google. Vui lòng thử lại.");
        }
    }

    public String clientId() { return clientId; }

    public boolean isConfigured() {
        // Reject copied documentation placeholders before invoking Google.
        // Token verification still validates the actual registered audience.
        return clientId.matches("[0-9]+-[A-Za-z0-9_-]+\\.apps\\.googleusercontent\\.com");
    }

    private GoogleAuthenticationException invalid() {
        return new GoogleAuthenticationException("Phiên Google không hợp lệ hoặc đã hết hạn. Vui lòng chọn lại tài khoản Google.");
    }
}
