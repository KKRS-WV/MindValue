package com.mindvault.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpdateProfileRequest(
    @NotBlank
    @Size(max = 100)
    String username,

    @NotBlank
    @Email
    @Size(max = 255)
    String email,

    @Size(max = 500)
    String avatar
) {
}
