package com.mindvault.knowledgebase;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record KnowledgeBaseRequest(
    @NotBlank @Size(max = 255) String name,
    String description,
    @Size(max = 255) String icon
) {
}
