package com.mindvault.node;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface KnowledgeNodeRepository extends JpaRepository<KnowledgeNode, Long> {

    List<KnowledgeNode> findByKnowledgeBaseId(Long knowledgeBaseId);

    Optional<KnowledgeNode> findByIdAndKnowledgeBaseUserId(Long id, Long userId);

    List<KnowledgeNode> findByTitleContainingIgnoreCaseOrDescriptionContainingIgnoreCase(
        String titleKeyword,
        String descriptionKeyword
    );
}
