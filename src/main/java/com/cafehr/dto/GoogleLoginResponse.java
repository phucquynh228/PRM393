package com.cafehr.dto;

public record GoogleLoginResponse(boolean linkRequired, String email, LoginResponse login) {}
