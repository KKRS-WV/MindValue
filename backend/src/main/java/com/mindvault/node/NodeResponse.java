package com.mindvault.node;

import java.time.Instant;

public record NodeResponse(
    Long id,
    Long knowledgeBaseId,
    Long parentId,
    String title,
    String description,
    Double positionX,
    Double positionY,
    Instant createdAt,
    Instant updatedAt
) {
}
