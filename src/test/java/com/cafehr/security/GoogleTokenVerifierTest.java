package com.cafehr.security;

import com.cafehr.exception.GoogleAuthenticationException;
import com.cafehr.exception.GoogleUnavailableException;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.googleapis.auth.oauth2.GooglePublicKeysManager;
import io.jsonwebtoken.Jwts;
import org.junit.jupiter.api.*;
import java.security.*;
import java.time.Instant;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class GoogleTokenVerifierTest {
    private static final String CLIENT = "1234567890-test-client.apps.googleusercontent.com";
    private KeyPair key;
    private GoogleTokenVerifier verifier;

    @BeforeEach void setup() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA"); generator.initialize(2048);
        key = generator.generateKeyPair();
        GooglePublicKeysManager keys = mock(GooglePublicKeysManager.class);
        when(keys.getPublicKeys()).thenReturn(List.of(key.getPublic()));
        verifier = new GoogleTokenVerifier(CLIENT, new GoogleIdTokenVerifier.Builder(keys).setAudience(List.of(CLIENT)).build());
    }

    String token(String audience, String issuer, Instant expires, boolean verified, PrivateKey signingKey) {
        return Jwts.builder().subject("google-subject-123").issuer(issuer).audience().add(audience).and()
                .issuedAt(Date.from(Instant.now().minusSeconds(7200))).expiration(Date.from(expires))
                .claim("email", "person@gmail.com").claim("email_verified", verified)
                .signWith(signingKey, Jwts.SIG.RS256).compact();
    }

    @Test void acceptsSignedTokenForThisApplication() {
        var identity = verifier.verify(token(CLIENT, "https://accounts.google.com", Instant.now().plusSeconds(3600), true, key.getPrivate()));
        assertEquals("google-subject-123", identity.subject()); assertEquals("person@gmail.com", identity.email());
    }
    @Test void acceptsGoogleLegacyIssuer() {
        assertNotNull(verifier.verify(token(CLIENT, "accounts.google.com", Instant.now().plusSeconds(3600), true, key.getPrivate())));
    }
    @Test void rejectsTokenForDifferentApplication() {
        assertThrows(GoogleAuthenticationException.class, () -> verifier.verify(token("other-app", "https://accounts.google.com",
                Instant.now().plusSeconds(3600), true, key.getPrivate())));
    }
    @Test void rejectsWrongIssuer() {
        assertThrows(GoogleAuthenticationException.class, () -> verifier.verify(token(CLIENT, "https://attacker.example",
                Instant.now().plusSeconds(3600), true, key.getPrivate())));
    }
    @Test void rejectsExpiredToken() {
        assertThrows(GoogleAuthenticationException.class, () -> verifier.verify(token(CLIENT, "https://accounts.google.com",
                Instant.now().minusSeconds(3600), true, key.getPrivate())));
    }
    @Test void rejectsForgedSignature() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA"); generator.initialize(2048);
        PrivateKey wrongKey = generator.generateKeyPair().getPrivate();
        assertThrows(GoogleAuthenticationException.class, () -> verifier.verify(token(CLIENT, "https://accounts.google.com",
                Instant.now().plusSeconds(3600), true, wrongKey)));
    }
    @Test void rejectsUnverifiedEmail() {
        assertThrows(GoogleAuthenticationException.class, () -> verifier.verify(token(CLIENT, "https://accounts.google.com",
                Instant.now().plusSeconds(3600), false, key.getPrivate())));
    }
    @Test void rejectsMalformedTokenAndMissingConfiguration() {
        assertThrows(GoogleAuthenticationException.class, () -> verifier.verify("not-a-jwt"));
        assertThrows(GoogleUnavailableException.class, () -> new GoogleTokenVerifier("").verify("anything"));
    }

    @Test void rejectsDocumentationPlaceholderBeforeCheckingToken() {
        GoogleTokenVerifier placeholder = new GoogleTokenVerifier("DAN_WEB_CLIENT_ID_CUA_BAN.apps.googleusercontent.com");
        assertFalse(placeholder.isConfigured());
        assertThrows(GoogleUnavailableException.class, () -> placeholder.verify("anything"));
        assertTrue(new GoogleTokenVerifier(CLIENT).isConfigured());
    }
}
