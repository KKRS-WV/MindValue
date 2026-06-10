package com.mindvault.auth;

public record UserProfileResponse(
    Long id,
    String username,
    String email,
    String avatar
) {
}
