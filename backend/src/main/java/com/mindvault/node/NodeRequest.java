package com.mindvault.node;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record NodeRequest(
    @NotNull Long knowledgeBaseId,
    Long parentId,
    @NotBlank @Size(max = 255) String title,
    String description,
    Double positionX,
    Double positionY
) {
}
