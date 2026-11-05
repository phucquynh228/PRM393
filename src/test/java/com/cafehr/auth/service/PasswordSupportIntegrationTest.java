package com.cafehr.auth.service;

import com.cafehr.auth.repository.PasswordSupportRepository;
import com.cafehr.user.entity.*;
import com.cafehr.user.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import java.util.concurrent.ThreadLocalRandom;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** SQL Server fixtures roll back; existing accounts and passwords remain untouched. */
@SpringBootTest(properties = {"spring.main.banner-mode=off", "spring.jpa.show-sql=false", "debug=false",
        "logging.level.org.springframework=ERROR", "logging.level.com.cafehr=ERROR", "logging.level.org.hibernate.SQL=ERROR"})
@AutoConfigureMockMvc @Transactional
@EnabledIfSystemProperty(named = "password.integration", matches = "true")
class PasswordSupportIntegrationTest {
    @Autowired UserRepository users;
    @Autowired PasswordSupportRepository requests;
    @Autowired PasswordEncoder passwords;
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired EntityManager entityManager;

    User create(Role role) {
        return users.saveAndFlush(User.builder().name("Kiểm thử hỗ trợ mật khẩu").role(role)
                .phone(String.format("08%010d", ThreadLocalRandom.current().nextLong(10_000_000_000L)))
                .password(passwords.encode("old-password")).build());
    }
    String login(User account, String password) throws Exception {
        String response = mvc.perform(post("/api/auth/login").contentType("application/json")
                .content("{\"phone\":\"" + account.getPhone() + "\",\"password\":\"" + password + "\",\"deviceId\":\"test-device\"}"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return json.readTree(response).path("data").path("token").asText();
    }

    @Test void anonymousReportAdminResetAndFreshLoginWorkWithPersistentAuditAndJwtRevocation() throws Exception {
        User employee = create(Role.STAFF), admin = create(Role.ADMIN);
        String oldToken = login(employee, "old-password");
        String report = "{\"phone\":\"" + employee.getPhone() + "\",\"name\":\"Tên tự khai\",\"note\":\"Gặp Admin trực tiếp\"}";
        for (int i = 0; i < 2; i++) mvc.perform(post("/api/auth/password-support").contentType("application/json").content(report))
                .andExpect(status().isAccepted()).andExpect(jsonPath("$.data").isEmpty());
        var pending = requests.findFirstByUserIdOrderByCreatedAtDesc(employee.getId()).orElseThrow();
        Long requestId = pending.getId();
        assertEquals("Tên tự khai", pending.getRequestedName());
        mvc.perform(put("/api/admin/password-support/" + requestId).with(user(admin.getPhone()).roles("ADMIN"))
                .contentType("application/json").content("{\"action\":\"RESOLVE\",\"identityVerified\":true,\"newPassword\":\"new-password\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.status").value("RESOLVED"))
                .andExpect(jsonPath("$.data.handledBy").value(admin.getName()))
                .andExpect(jsonPath("$.data.newPassword").doesNotExist());
        users.flush(); requests.flush(); entityManager.clear();
        var saved = users.findById(employee.getId()).orElseThrow();
        assertTrue(passwords.matches("new-password", saved.getPassword()));
        assertEquals(1, saved.getCredentialsVersion());
        assertNotNull(requests.findById(requestId).orElseThrow().getHandledAt());
        mvc.perform(get("/api/schedules/today").header("Authorization", "Bearer " + oldToken)).andExpect(status().isForbidden());
        mvc.perform(post("/api/auth/login").contentType("application/json")
                .content("{\"phone\":\"" + saved.getPhone() + "\",\"password\":\"old-password\",\"deviceId\":\"test-device\"}"))
                .andExpect(status().isUnauthorized());
        String newToken = login(saved, "new-password");
        mvc.perform(get("/api/schedules/today").header("Authorization", "Bearer " + newToken)).andExpect(status().isOk());
        mvc.perform(delete("/api/admin/users/" + saved.getId()).with(user(admin.getPhone()).roles("ADMIN")))
                .andExpect(status().isBadRequest());
        assertTrue(users.existsById(saved.getId()));
    }
}
