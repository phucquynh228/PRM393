package com.cafehr.auth.dto;

import java.time.LocalDateTime;

public record PasswordSupportView(Long id, Long userId, String name, String phone, String role,
        String storeName, String requestedName, String note, String status, LocalDateTime createdAt,
        LocalDateTime handledAt, String handledBy, String adminNote) {}
