package com.cafehr.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter @Setter
public class GoogleLinkRequest extends GoogleLoginRequest {
    @NotBlank @Size(max = 15)
    private String phone;
    @NotBlank @Size(max = 255)
    private String password;
}
