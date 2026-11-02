package com.cafehr.auth.dto;

public record GoogleLoginResponse(boolean linkRequired, String email, LoginResponse login) {}
