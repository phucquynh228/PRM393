package com.cafehr.branch.controller;

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
@EnabledIfSystemProperty(named="staff.integration", matches="true")
class ManagerProfileIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired PasswordEncoder passwords;
    @Autowired EntityManager em;

    @Test void managerWithoutAssignedBranchCanPersistOwnProfileAndPassword() throws Exception {
        var account = users.saveAndFlush(User.builder().name("Manager kiểm thử").role(Role.MANAGER)
                .phone("QA" + UUID.randomUUID().toString().substring(0,10)).password(passwords.encode("old-password")).build());
        Long id = account.getId(); String phone = account.getPhone();
        mvc.perform(put("/api/manager/profile").with(user(phone).roles("MANAGER")).contentType("application/json")
                .content("{\"name\":\"Quản lý cập nhật\",\"email\":\"manager@example.com\",\"address\":\"Thủ Đức\",\"emergencyContact\":\"0901234567\"}"))
                .andExpect(status().isOk());
        mvc.perform(put("/api/manager/password").with(user(phone).roles("MANAGER")).contentType("application/json")
                .content("{\"currentPassword\":\"old-password\",\"newPassword\":\"new-password\"}"))
                .andExpect(status().isOk());
        users.flush(); em.clear();
        var stored = users.findById(id).orElseThrow();
        assertEquals("Quản lý cập nhật", stored.getName()); assertEquals(phone, stored.getPhone());
        assertEquals(Role.MANAGER, stored.getRole()); assertNull(stored.getStore());
        assertEquals("0901234567", stored.getEmergencyContact()); assertEquals("Thủ Đức", stored.getAddress());
        assertTrue(passwords.matches("new-password", stored.getPassword()));
        mvc.perform(get("/api/manager/profile").with(user(phone).roles("MANAGER")))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.name").value("Quản lý cập nhật"));
    }
}
