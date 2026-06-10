package com.mindvault.knowledgebase;

import java.time.Instant;

public record KnowledgeBaseResponse(
    Long id,
    String name,
    String description,
    String icon,
    Instant createdAt,
    Instant updatedAt
) {
}
