package com.cafehr.service;

import com.cafehr.entity.*;
import com.cafehr.repository.*;
import com.cafehr.security.GoogleTokenVerifier;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties = {"spring.main.banner-mode=off", "spring.jpa.show-sql=false", "debug=false",
        "logging.level.org.springframework=ERROR", "logging.level.com.cafehr=ERROR", "logging.level.org.hibernate.SQL=ERROR"})
@AutoConfigureMockMvc @Transactional
@EnabledIfSystemProperty(named = "google.integration", matches = "true")
class GoogleAuthIntegrationTest {
    @Autowired UserRepository users;
    @Autowired GoogleAccountRepository accounts;
    @Autowired PasswordEncoder passwords;
    @Autowired MockMvc mvc;
    @MockBean GoogleTokenVerifier verifier;

    User createUser(Role role) {
        String key = UUID.randomUUID().toString().replace("-", "").substring(0, 10);
        return users.saveAndFlush(User.builder().name("Kiểm thử Google").phone("QA" + key).role(role)
                .password(passwords.encode("123456")).email("person@gmail.com").build());
    }
    void verifyIdentity(User account) {
        when(verifier.verify("verified-google-token")).thenReturn(new GoogleTokenVerifier.Identity(
                "test-sub-" + account.getId(), "person@gmail.com"));
    }
    String googleBody() { return "{\"idToken\":\"verified-google-token\",\"deviceId\":\"google-test-device\"}"; }
    String linkBody(User account, String password) {
        return "{\"idToken\":\"verified-google-token\",\"deviceId\":\"google-test-device\",\"phone\":\""
                + account.getPhone() + "\",\"password\":\"" + password + "\"}";
    }

    @ParameterizedTest @EnumSource(Role.class)
    void firstLinkAndLaterGoogleLoginKeepExistingRole(Role role) throws Exception {
        User account = createUser(role); verifyIdentity(account);
        mvc.perform(post("/api/auth/google").contentType("application/json").content(googleBody()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.linkRequired").value(true))
                .andExpect(jsonPath("$.data.login").isEmpty());
        // An editable profile email is never treated as proof of account ownership.
        assertTrue(accounts.findByUserId(account.getId()).isEmpty());
        mvc.perform(post("/api/auth/google/link").contentType("application/json").content(linkBody(account, "123456")))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.role").value(role.name()))
                .andExpect(jsonPath("$.data.token").isNotEmpty());
        assertEquals("test-sub-" + account.getId(), accounts.findByUserId(account.getId()).orElseThrow().getSubject());
        mvc.perform(post("/api/auth/google").contentType("application/json").content(googleBody()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.linkRequired").value(false))
                .andExpect(jsonPath("$.data.login.role").value(role.name()))
                .andExpect(jsonPath("$.data.login.userId").value(account.getId()));
        assertEquals(role, users.findById(account.getId()).orElseThrow().getRole());
    }

    @Test void wrongPasswordDoesNotLinkIdentity() throws Exception {
        User account = createUser(Role.STAFF); verifyIdentity(account);
        mvc.perform(post("/api/auth/google/link").contentType("application/json").content(linkBody(account, "wrong-password")))
                .andExpect(status().isUnauthorized());
        assertTrue(accounts.findByUserId(account.getId()).isEmpty());
    }

    @Test void googleConfigAndLocalWebCorsAreAvailableWithoutLogin() throws Exception {
        when(verifier.clientId()).thenReturn("1234567890-test-client.apps.googleusercontent.com");
        when(verifier.isConfigured()).thenReturn(true);
        mvc.perform(get("/api/auth/google/config")).andExpect(status().isOk())
                .andExpect(jsonPath("$.data.enabled").value(true));
        mvc.perform(options("/api/auth/google").header("Origin", "http://localhost:7357")
                .header("Access-Control-Request-Method", "POST").header("Access-Control-Request-Headers", "content-type"))
                .andExpect(status().isOk()).andExpect(header().string("Access-Control-Allow-Origin", "http://localhost:7357"));
    }

    @Test void adminCanDeleteUserAndTheirGoogleLinkTogether() throws Exception {
        User account = createUser(Role.STAFF);
        accounts.saveAndFlush(GoogleAccount.builder().subject("delete-test-" + account.getId()).user(account).email("person@gmail.com").build());
        mvc.perform(delete("/api/admin/users/" + account.getId()).with(user("admin").roles("ADMIN")))
                .andExpect(status().isOk());
        users.flush();
        assertFalse(users.existsById(account.getId())); assertTrue(accounts.findByUserId(account.getId()).isEmpty());
    }
}
