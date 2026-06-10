package com.mindvault.document;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record DocumentRequest(
    @NotNull Long nodeId,
    @NotBlank @Size(max = 255) String title,
    String content
) {
}
