package com.mindvault.document;

import java.time.Instant;

public record DocumentResponse(
    Long id,
    Long nodeId,
    String title,
    String content,
    Instant createdAt,
    Instant updatedAt
) {
}
