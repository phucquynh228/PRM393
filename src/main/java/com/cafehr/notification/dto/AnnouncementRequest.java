package com.cafehr.notification.dto;

import jakarta.validation.constraints.*;
import lombok.Data;

@Data
public class AnnouncementRequest {
    @NotBlank @Size(max = 150)
    private String title;
    @NotBlank @Size(max = 2000)
    private String message;
}
