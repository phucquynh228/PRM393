package com.cafehr.admin.controller;

import com.cafehr.system.repository.SystemConfigRepository;
import com.cafehr.user.entity.*;
import com.cafehr.user.repository.UserRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties={"spring.main.banner-mode=off", "spring.jpa.show-sql=false", "debug=false",
        "logging.level.org.springframework=ERROR", "logging.level.com.cafehr=ERROR", "logging.level.org.hibernate.SQL=ERROR"})
@AutoConfigureMockMvc @Transactional
@EnabledIfSystemProperty(named="admin.profile.integration", matches="true")
class AdminProfileIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired SystemConfigRepository settings;
    @Autowired PasswordEncoder passwords;
    @Autowired EntityManager em;

    @Test void ownProfilePasswordAndReminderSettingsPersistWithoutChangingRoleOrPhone() throws Exception {
        var account = users.saveAndFlush(User.builder().name("Admin kiểm thử").role(Role.ADMIN)
                .phone("QA" + UUID.randomUUID().toString().substring(0,10)).password(passwords.encode("old-password")).build());
        Long id = account.getId(); String phone = account.getPhone();
        mvc.perform(put("/api/admin/profile").with(user(phone).roles("ADMIN")).contentType("application/json")
                .content("{\"name\":\"Admin cập nhật\",\"email\":\"admin@example.com\",\"address\":\"Hà Nội\"}"))
                .andExpect(status().isOk());
        mvc.perform(put("/api/admin/profile/password").with(user(phone).roles("ADMIN")).contentType("application/json")
                .content("{\"currentPassword\":\"old-password\",\"newPassword\":\"new-password\"}"))
                .andExpect(status().isOk());
        mvc.perform(put("/api/admin/settings").with(user(phone).roles("ADMIN")).contentType("application/json")
                .content("{\"reminderMinutes\":17}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.reminderMinutes").value(17));
        users.flush(); settings.flush(); em.clear();
        var stored = users.findById(id).orElseThrow();
        assertEquals("Admin cập nhật", stored.getName()); assertEquals(phone, stored.getPhone()); assertEquals(Role.ADMIN, stored.getRole());
        assertTrue(passwords.matches("new-password", stored.getPassword())); assertEquals(1, stored.getCredentialsVersion());
        assertEquals("17", settings.findByConfigKey("reminder_minutes").orElseThrow().getConfigValue());
    }
}
