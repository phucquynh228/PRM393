package com.cafehr.auth.controller;

import com.cafehr.admin.controller.AdminPasswordSupportController;
import com.cafehr.auth.entity.PasswordSupportRequest.Status;
import com.cafehr.auth.service.PasswordSupportService;
import com.cafehr.config.SecurityConfig;
import com.cafehr.security.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import java.util.List;
import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(value = {PasswordSupportController.class, AdminPasswordSupportController.class},
        properties = {"debug=false", "logging.level.org.springframework=ERROR", "logging.level.com.cafehr=ERROR"})
@Import({SecurityConfig.class, JwtAuthenticationFilter.class})
class PasswordSupportControllerTest {
    @Autowired MockMvc mvc;
    @MockBean PasswordSupportService support;
    @MockBean CustomUserDetailsService users;
    @MockBean JwtUtil jwt;

    @Test void anonymousSubmissionReturnsOnlyGenericAcknowledgement() throws Exception {
        mvc.perform(post("/api/auth/password-support").contentType(MediaType.APPLICATION_JSON)
                .content("{\"phone\":\"0901000003\",\"name\":\"Nhân viên\"}"))
                .andExpect(status().isAccepted()).andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.message").value(PasswordSupportService.ACKNOWLEDGEMENT))
                .andExpect(jsonPath("$.data").isEmpty()).andExpect(header().string("Cache-Control", "no-store"));
    }
    @Test void invalidPublicSubmissionDoesNotReachService() throws Exception {
        mvc.perform(post("/api/auth/password-support").contentType(MediaType.APPLICATION_JSON)
                .content("{\"phone\":\"bad\",\"name\":\" \"}"))
                .andExpect(status().isBadRequest()); verifyNoInteractions(support);
    }
    @Test void onlyAdminCanListAndResolveRequests() throws Exception {
        for (String role : new String[]{"STAFF", "MANAGER"}) {
            mvc.perform(get("/api/admin/password-support").with(user("employee").roles(role))).andExpect(status().isForbidden());
            mvc.perform(put("/api/admin/password-support/5").with(user("employee").roles(role))
                    .contentType(MediaType.APPLICATION_JSON).content("{\"action\":\"RESOLVE\",\"identityVerified\":true,\"newPassword\":\"new-password\"}"))
                    .andExpect(status().isForbidden());
        }
        mvc.perform(get("/api/admin/password-support")).andExpect(status().isForbidden());
        mvc.perform(put("/api/admin/password-support/5").contentType(MediaType.APPLICATION_JSON).content("{\"action\":\"REJECT\"}"))
                .andExpect(status().isForbidden());
        verifyNoInteractions(support);
    }
    @Test void adminCanListAndDecideUsingAuthenticatedIdentity() throws Exception {
        when(support.list(Status.PENDING)).thenReturn(List.of());
        mvc.perform(get("/api/admin/password-support").with(user("0901000001").roles("ADMIN")))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data").isArray());
        mvc.perform(put("/api/admin/password-support/5").with(user("0901000001").roles("ADMIN"))
                .contentType(MediaType.APPLICATION_JSON).content("{\"action\":\"REJECT\",\"adminNote\":\"Không xác minh được\"}"))
                .andExpect(status().isOk());
        verify(support).decide(eq(5L), eq("0901000001"), any());
    }

    @Test void invalidStatusReturnsReadableClientError() throws Exception {
        mvc.perform(get("/api/admin/password-support").param("status", "INVALID")
                .with(user("admin").roles("ADMIN"))).andExpect(status().isBadRequest());
        verifyNoInteractions(support);
    }
}
