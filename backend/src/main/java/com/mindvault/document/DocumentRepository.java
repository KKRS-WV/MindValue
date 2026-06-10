package com.mindvault.document;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DocumentRepository extends JpaRepository<Document, Long> {

    Optional<Document> findByNodeId(Long nodeId);

    Optional<Document> findByIdAndNodeKnowledgeBaseUserId(Long id, Long userId);

    Optional<Document> findByNodeIdAndNodeKnowledgeBaseUserId(Long nodeId, Long userId);

    List<Document> findByTitleContainingIgnoreCaseOrContentContainingIgnoreCase(
        String titleKeyword,
        String contentKeyword
    );
}
