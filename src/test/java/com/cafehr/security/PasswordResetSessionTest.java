package com.cafehr.security;

import com.cafehr.user.entity.*;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import static org.junit.jupiter.api.Assertions.*;

class PasswordResetSessionTest {
    @Test void passwordResetInvalidatesOldJwtAndNewLoginUsesNewVersion() {
        var jwt = new JwtUtil();
        ReflectionTestUtils.setField(jwt, "secretKey", "dGVzdC1zZWNyZXQta2V5LXdpdGgtYXQtbGVhc3QtMzItYnl0ZXMtbG9uZw==");
        ReflectionTestUtils.setField(jwt, "expirationMs", 60000L);
        var user = User.builder().id(3L).phone("0901000003").password("bcrypt-hash").role(Role.STAFF).build();
        String previous = jwt.generateToken(user.getPhone(), 3L, "STAFF");
        assertTrue(jwt.validateToken(previous, new HrmUserDetails(user)));
        user.setCredentialsVersion(1);
        assertFalse(jwt.validateToken(previous, new HrmUserDetails(user)));
        String next = jwt.generateToken(user.getPhone(), 3L, "STAFF", user.getCredentialsVersion());
        assertTrue(jwt.validateToken(next, new HrmUserDetails(user)));
    }
}
