package com.cafehr.admin.controller;

import com.cafehr.auth.repository.GoogleAccountRepository;
import com.cafehr.config.SecurityConfig;
import com.cafehr.security.*;
import com.cafehr.system.repository.SystemConfigRepository;
import com.cafehr.user.entity.*;
import com.cafehr.user.repository.UserRepository;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.security.crypto.password.PasswordEncoder;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(value=AdminProfileController.class, properties={"debug=false", "logging.level.org.springframework=ERROR", "logging.level.com.cafehr=ERROR"})
@Import({SecurityConfig.class, JwtAuthenticationFilter.class})
class AdminProfileControllerTest {
    @Autowired MockMvc mvc;
    @Autowired PasswordEncoder passwords;
    @MockBean UserRepository users;
    @MockBean GoogleAccountRepository google;
    @MockBean SystemConfigRepository settings;
    @MockBean CustomUserDetailsService details;
    @MockBean JwtUtil jwt;
    User admin;
    @BeforeEach void setup() {
        admin = User.builder().id(1L).name("Admin").phone("0901000001").role(Role.ADMIN)
                .password(passwords.encode("old-password")).build();
    }
    void current() {
        when(users.findByPhone(admin.getPhone())).thenReturn(Optional.of(admin));
        when(users.findLockedById(1L)).thenReturn(Optional.of(admin));
    }
    @Test void staffManagerAndAnonymousCannotAccessProfileOrSettings() throws Exception {
        for (String path : new String[]{"/api/admin/profile", "/api/admin/settings"}) {
            mvc.perform(get(path)).andExpect(status().isForbidden());
            for (String role : new String[]{"STAFF", "MANAGER"})
                mvc.perform(get(path).with(user("staff").roles(role))).andExpect(status().isForbidden());
        }
        verifyNoInteractions(users, settings);
    }
    @Test void profileUsesAuthenticatedIdentityAndDoesNotExposeCredentials() throws Exception {
        when(users.findByPhone(admin.getPhone())).thenReturn(Optional.of(admin));
        mvc.perform(get("/api/admin/profile").with(user(admin.getPhone()).roles("ADMIN")))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.id").value(1))
                .andExpect(jsonPath("$.data.password").doesNotExist()).andExpect(jsonPath("$.data.credentialsVersion").doesNotExist());
    }
    @Test void updatingProfileCannotChangeLoginPhoneOrRole() throws Exception {
        current();
        mvc.perform(put("/api/admin/profile").with(user(admin.getPhone()).roles("ADMIN"))
                .contentType("application/json").content("{\"name\":\"Tên mới\",\"email\":\"admin@example.com\",\"address\":\"Hà Nội\",\"role\":\"STAFF\",\"phone\":\"0000000000\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.name").value("Tên mới"));
        assertEquals(Role.ADMIN, admin.getRole()); assertEquals("0901000001", admin.getPhone());
    }
    @Test void passwordChangeRequiresCurrentPasswordAndRevokesOldSessions() throws Exception {
        current(); String previous = admin.getPassword();
        mvc.perform(put("/api/admin/profile/password").with(user(admin.getPhone()).roles("ADMIN"))
                .contentType("application/json").content("{\"currentPassword\":\"wrong\",\"newPassword\":\"new-password\"}"))
                .andExpect(status().isBadRequest());
        assertEquals(previous, admin.getPassword());
        mvc.perform(put("/api/admin/profile/password").with(user(admin.getPhone()).roles("ADMIN"))
                .contentType("application/json").content("{\"currentPassword\":\"old-password\",\"newPassword\":\"new-password\"}"))
                .andExpect(status().isOk());
        assertTrue(passwords.matches("new-password", admin.getPassword())); assertEquals(1, admin.getCredentialsVersion());
    }
    @Test void settingsAreValidatedAndStoredUsingReminderKey() throws Exception {
        mvc.perform(put("/api/admin/settings").with(user("admin").roles("ADMIN")).contentType("application/json")
                .content("{\"reminderMinutes\":0}" )).andExpect(status().isBadRequest());
        verifyNoInteractions(settings);
        mvc.perform(put("/api/admin/settings").with(user("admin").roles("ADMIN")).contentType("application/json")
                .content("{\"reminderMinutes\":15}" )).andExpect(status().isOk());
        verify(settings).save(argThat(s -> s.getConfigKey().equals("reminder_minutes") && s.getConfigValue().equals("15")));
    }
}
