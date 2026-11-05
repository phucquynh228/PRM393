package com.cafehr.branch.controller;

import com.cafehr.config.SecurityConfig;
import com.cafehr.security.*;
import com.cafehr.user.entity.*;
import com.cafehr.user.repository.UserRepository;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(value=ManagerProfileController.class, properties={"debug=false", "logging.level.org.springframework=ERROR", "logging.level.com.cafehr=ERROR"})
@Import({SecurityConfig.class, JwtAuthenticationFilter.class})
class ManagerProfileControllerTest {
    @Autowired MockMvc mvc;
    @Autowired PasswordEncoder passwords;
    @MockBean UserRepository users;
    @MockBean CustomUserDetailsService details;
    @MockBean JwtUtil jwt;
    User manager;

    @BeforeEach void setup() {
        manager = User.builder().id(2L).name("Manager").phone("0901000002").role(Role.MANAGER)
                .password(passwords.encode("old-password")).build();
        when(users.findByPhone(manager.getPhone())).thenReturn(Optional.of(manager));
        when(users.findLockedById(manager.getId())).thenReturn(Optional.of(manager));
    }

    @Test void onlyManagerCanReadOrWriteManagerProfile() throws Exception {
        mvc.perform(get("/api/manager/profile")).andExpect(status().isForbidden());
        for (String role : new String[]{"STAFF", "ADMIN"}) {
            mvc.perform(get("/api/manager/profile").with(user("other").roles(role))).andExpect(status().isForbidden());
            mvc.perform(put("/api/manager/password").with(user("other").roles(role)).contentType("application/json")
                    .content("{\"currentPassword\":\"old-password\",\"newPassword\":\"new-password\"}"))
                    .andExpect(status().isForbidden());
        }
        verify(users, never()).findByPhone(anyString());
    }

    @Test void identityComesFromSessionAndProfileContainsNoSecrets() throws Exception {
        mvc.perform(get("/api/manager/profile?id=999").with(user(manager.getPhone()).roles("MANAGER")))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.id").value(2))
                .andExpect(jsonPath("$.data.password").doesNotExist()).andExpect(jsonPath("$.data.deviceId").doesNotExist());
    }

    @Test void selfUpdateDoesNotChangeRolePhoneOrStoreAndRejectsInvalidFields() throws Exception {
        mvc.perform(put("/api/manager/profile").with(user(manager.getPhone()).roles("MANAGER")).contentType("application/json")
                .content("{\"name\":\" \",\"email\":\"invalid\"}" )).andExpect(status().isBadRequest());
        assertEquals("Manager", manager.getName());
        mvc.perform(put("/api/manager/profile").with(user(manager.getPhone()).roles("MANAGER")).contentType("application/json")
                .content("{\"id\":999,\"name\":\" New Name \",\"email\":\"manager@example.com\",\"emergencyContact\":\"0901234567\",\"address\":\"HCM\",\"phone\":\"0000000000\",\"role\":\"ADMIN\",\"storeId\":999}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.name").value("New Name"));
        assertEquals(Role.MANAGER, manager.getRole()); assertEquals("0901000002", manager.getPhone());
        assertEquals(2L, manager.getId()); assertNull(manager.getStore());
        assertEquals("0901234567", manager.getEmergencyContact());
    }

    @Test void passwordChangeRequiresProofAndRejectsReuseAndOversizeUtf8() throws Exception {
        String previous = manager.getPassword();
        for (String body : new String[]{
            "{\"currentPassword\":\"wrong\",\"newPassword\":\"new-password\"}",
            "{\"currentPassword\":\"old-password\",\"newPassword\":\"old-password\"}",
            "{\"currentPassword\":\"old-password\",\"newPassword\":\"" + "ế".repeat(25) + "\"}"
        }) {
            mvc.perform(put("/api/manager/password").with(user(manager.getPhone()).roles("MANAGER")).contentType("application/json")
                    .content(body)).andExpect(status().isBadRequest());
            assertEquals(previous, manager.getPassword());
        }
        mvc.perform(put("/api/manager/password").with(user(manager.getPhone()).roles("MANAGER")).contentType("application/json")
                .content("{\"currentPassword\":\"old-password\",\"newPassword\":\"new-password\"}"))
                .andExpect(status().isOk());
        assertTrue(passwords.matches("new-password", manager.getPassword()));
    }
}
