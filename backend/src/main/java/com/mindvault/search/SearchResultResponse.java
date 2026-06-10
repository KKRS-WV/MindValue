package com.mindvault.search;

public record SearchResultResponse(
    Long nodeId,
    String nodeTitle,
    String matchedField,
    String snippet
) {
}
