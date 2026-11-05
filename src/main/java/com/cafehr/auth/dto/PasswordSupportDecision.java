package com.cafehr.auth.dto;

import jakarta.validation.constraints.*;
import lombok.*;

@Getter @Setter @NoArgsConstructor
public class PasswordSupportDecision {
    @NotBlank @Pattern(regexp = "RESOLVE|REJECT")
    private String action;
    private boolean identityVerified;
    @ToString.Exclude
    private String newPassword;
    @Size(max = 500)
    private String adminNote;
}
