package com.cafehr.auth.service;

import com.cafehr.auth.dto.*;
import com.cafehr.auth.entity.PasswordSupportRequest;
import com.cafehr.auth.entity.PasswordSupportRequest.Status;
import com.cafehr.auth.repository.PasswordSupportRepository;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.user.entity.*;
import com.cafehr.user.repository.UserRepository;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import java.time.LocalDateTime;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PasswordSupportServiceTest {
    @Mock UserRepository users;
    @Mock PasswordSupportRepository requests;
    final BCryptPasswordEncoder passwords = new BCryptPasswordEncoder(4);
    PasswordSupportService service;
    User employee, admin;
    PasswordSupportRequest request;

    @BeforeEach void setup() {
        service = new PasswordSupportService(users, requests, passwords);
        employee = User.builder().id(3L).name("Nhân viên").phone("0901000003").role(Role.STAFF)
                .password(passwords.encode("old-password")).deviceId("existing-device").build();
        admin = User.builder().id(1L).name("Admin").phone("0901000001").role(Role.ADMIN).build();
        request = new PasswordSupportRequest(); request.setId(5L); request.setUser(employee); request.setRequestedName("Tự khai");
    }

    PasswordSupportSubmission submission() { return new PasswordSupportSubmission(employee.getPhone(), " Tự khai ", " Gặp Admin "); }
    void existingEmployee() {
        when(users.findByPhone(employee.getPhone())).thenReturn(Optional.of(employee));
        when(users.findLockedById(3L)).thenReturn(Optional.of(employee));
    }
    void pending() {
        when(users.findByPhone(admin.getPhone())).thenReturn(Optional.of(admin));
        when(requests.findById(5L)).thenReturn(Optional.of(request));
        when(users.findLockedById(3L)).thenReturn(Optional.of(employee));
        when(requests.findLockedById(5L)).thenReturn(Optional.of(request));
    }
    PasswordSupportDecision decision(String action) {
        var body = new PasswordSupportDecision(); body.setAction(action); body.setIdentityVerified(true);
        body.setNewPassword("new-password"); body.setAdminNote("Đã gặp trực tiếp"); return body;
    }

    @Test void anonymousReportOnlyCreatesPendingRequestAndNeverChangesCredentials() {
        existingEmployee(); String before = employee.getPassword();
        service.submit(submission());
        var saved = ArgumentCaptor.forClass(PasswordSupportRequest.class); verify(requests).save(saved.capture());
        assertEquals(Status.PENDING, saved.getValue().getStatus());
        assertEquals("Tự khai", saved.getValue().getRequestedName());
        assertEquals("Gặp Admin", saved.getValue().getNote());
        assertEquals(before, employee.getPassword()); verify(users, never()).save(any());
    }
    @Test void unknownPhoneCreatesNoRequest() {
        service.submit(submission()); verifyNoInteractions(requests);
    }
    @Test void anonymousReportsCannotResetOrQueueAdminAccounts() {
        existingEmployee(); employee.setRole(Role.ADMIN);
        service.submit(submission()); verifyNoInteractions(requests);
    }
    @Test void repeatedReportsPreserveOriginalPendingRequest() {
        existingEmployee(); when(requests.findFirstByUserIdOrderByCreatedAtDesc(3L)).thenReturn(Optional.of(request));
        service.submit(submission()); verify(requests, never()).save(any()); assertEquals("Tự khai", request.getRequestedName());
    }
    @Test void recentlyHandledRequestHasCooldown() {
        existingEmployee(); request.setStatus(Status.REJECTED);
        when(requests.findFirstByUserIdOrderByCreatedAtDesc(3L)).thenReturn(Optional.of(request));
        service.submit(submission()); verify(requests, never()).save(any());
        request.setCreatedAt(LocalDateTime.now().minusMinutes(6)); service.submit(submission()); verify(requests).save(any());
    }
    @Test void resetRequiresVerifiedIdentity() {
        pending(); var body = decision("RESOLVE"); body.setIdentityVerified(false); String before = employee.getPassword();
        assertThrows(BusinessException.class, () -> service.decide(5L, admin.getPhone(), body));
        assertEquals(before, employee.getPassword()); assertEquals(Status.PENDING, request.getStatus());
        verify(users, never()).save(any());
    }
    @Test void resetHashesPasswordRecordsAdminAndRevokesExistingSessionsWithoutChangingDeviceOrRole() {
        pending(); employee.setCredentialsVersion(4);
        var result = service.decide(5L, admin.getPhone(), decision("RESOLVE"));
        assertTrue(passwords.matches("new-password", employee.getPassword()));
        assertFalse(passwords.matches("old-password", employee.getPassword()));
        assertEquals(5, employee.getCredentialsVersion()); assertEquals("existing-device", employee.getDeviceId());
        assertEquals(Role.STAFF, employee.getRole()); assertEquals(Status.RESOLVED, request.getStatus());
        assertEquals(admin, request.getHandledBy()); assertNotNull(request.getHandledAt());
        assertFalse(result.toString().contains("new-password")); assertFalse(result.toString().contains(employee.getPassword()));
    }
    @Test void invalidOrReusedPasswordsAreRejected() {
        pending();
        for (String password : new String[]{"short", " ".repeat(9), "é".repeat(40), "old-password"}) {
            var body = decision("RESOLVE"); body.setNewPassword(password);
            assertThrows(BusinessException.class, () -> service.decide(5L, admin.getPhone(), body));
        }
        assertEquals(Status.PENDING, request.getStatus()); verify(users, never()).save(any());
    }
    @Test void rejectionNeedsReasonAndLeavesPasswordAndSessionsUnchanged() {
        pending(); String before = employee.getPassword(); var body = decision("REJECT"); body.setAdminNote(" ");
        assertThrows(BusinessException.class, () -> service.decide(5L, admin.getPhone(), body));
        body.setAdminNote("Không xác minh được danh tính"); service.decide(5L, admin.getPhone(), body);
        assertEquals(Status.REJECTED, request.getStatus()); assertEquals(before, employee.getPassword());
        assertEquals(0, employee.getCredentialsVersion()); verify(users, never()).save(any());
    }
    @Test void handledRequestCannotResetPasswordAgain() {
        pending(); request.setStatus(Status.RESOLVED);
        assertThrows(BusinessException.class, () -> service.decide(5L, admin.getPhone(), decision("RESOLVE")));
        verify(users, never()).save(any());
    }
    @Test void nonAdminCannotHandleRequestEvenWhenCallingServiceDirectly() {
        when(users.findByPhone(employee.getPhone())).thenReturn(Optional.of(employee));
        assertThrows(AccessDeniedException.class, () -> service.decide(5L, employee.getPhone(), decision("RESOLVE")));
        verifyNoInteractions(requests);
    }
}
