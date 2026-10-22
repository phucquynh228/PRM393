package com.cafehr.service;

import com.cafehr.dto.*;
import com.cafehr.entity.*;
import com.cafehr.exception.*;
import com.cafehr.repository.*;
import com.cafehr.security.GoogleTokenVerifier;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class GoogleAuthServiceTest {
    @Mock GoogleTokenVerifier verifier;
    @Mock GoogleAccountRepository accounts;
    @Mock UserRepository users;
    @Mock AuthenticationManager authenticationManager;
    @Mock AuthService auth;
    @InjectMocks GoogleAuthService service;
    User user;
    @BeforeEach void setup() {
        user = User.builder().id(3L).phone("0901000003").role(Role.STAFF).name("Staff").build();
    }
    GoogleLoginRequest loginRequest() {
        GoogleLoginRequest request = new GoogleLoginRequest(); request.setIdToken("google-token"); request.setDeviceId("device"); return request;
    }
    GoogleLinkRequest linkRequest() {
        GoogleLinkRequest request = new GoogleLinkRequest(); request.setIdToken("google-token"); request.setDeviceId("device");
        request.setPhone(user.getPhone()); request.setPassword("test-password"); return request;
    }
    void verified() { when(verifier.verify("google-token")).thenReturn(new GoogleTokenVerifier.Identity("google-sub", "person@gmail.com")); }
    void authenticatedUser() {
        when(users.findByPhone(user.getPhone())).thenReturn(Optional.of(user));
        when(users.findLockedById(user.getId())).thenReturn(Optional.of(user));
    }
    @Test void unlinkedGoogleRequiresProofOfHrmAccountAndCreatesNoUser() {
        verified(); var result = service.login(loginRequest());
        assertTrue(result.linkRequired()); assertNull(result.login());
        verifyNoInteractions(auth, users, authenticationManager);
        verify(accounts, never()).saveAndFlush(any());
    }
    @Test void linkedGoogleGetsExistingRoleAndSession() {
        verified(); when(accounts.findBySubject("google-sub")).thenReturn(Optional.of(GoogleAccount.builder().subject("google-sub").user(user).build()));
        when(auth.createSession(user, "device")).thenReturn(LoginResponse.builder().role("STAFF").token("app-jwt").build());
        var result = service.login(loginRequest());
        assertFalse(result.linkRequired()); assertEquals("STAFF", result.login().getRole());
        verifyNoInteractions(authenticationManager); verify(users, never()).save(any());
    }
    @Test void invalidGoogleTokenNeverReachesAccountLookupOrSessionCreation() {
        when(verifier.verify("google-token")).thenThrow(new GoogleAuthenticationException("Invalid"));
        assertThrows(GoogleAuthenticationException.class, () -> service.login(loginRequest()));
        verifyNoInteractions(accounts, auth, users);
    }
    @Test void badHrmPasswordCannotLinkGoogle() {
        verified(); when(authenticationManager.authenticate(any())).thenThrow(new BadCredentialsException("wrong"));
        assertThrows(BadCredentialsException.class, () -> service.link(linkRequest()));
        verifyNoInteractions(accounts, auth, users);
    }
    @Test void linkRequiresPasswordAndRetainsHrmRole() {
        verified(); authenticatedUser();
        service.link(linkRequest());
        ArgumentCaptor<GoogleAccount> saved = ArgumentCaptor.forClass(GoogleAccount.class);
        verify(accounts).saveAndFlush(saved.capture());
        assertEquals(user, saved.getValue().getUser()); assertEquals("google-sub", saved.getValue().getSubject());
        assertEquals(Role.STAFF, user.getRole()); verify(authenticationManager).authenticate(any());
        verify(auth).createSession(user, "device");
    }
    @Test void googleAlreadyLinkedToSomeoneElseCannotBeReassigned() {
        verified(); authenticatedUser();
        User other = User.builder().id(99L).build();
        when(accounts.findBySubject("google-sub")).thenReturn(Optional.of(GoogleAccount.builder().subject("google-sub").user(other).build()));
        assertThrows(BusinessException.class, () -> service.link(linkRequest())); verifyNoInteractions(auth);
    }
    @Test void cannotOverwriteAnotherGoogleIdentityForSameHrmAccount() {
        verified(); authenticatedUser();
        when(accounts.findByUserId(user.getId())).thenReturn(Optional.of(GoogleAccount.builder().subject("different-google").user(user).build()));
        assertThrows(BusinessException.class, () -> service.link(linkRequest())); verifyNoInteractions(auth);
    }
    @Test void sensitiveTokensAndPasswordsAreExcludedFromLogs() {
        assertFalse(loginRequest().toString().contains("google-token"));
        assertFalse(linkRequest().toString().contains("test-password"));
        assertFalse(LoginResponse.builder().token("secret-jwt").build().toString().contains("secret-jwt"));
        assertFalse(new LoginRequest("phone", "secret-password", "device").toString().contains("secret-password"));
    }
}
