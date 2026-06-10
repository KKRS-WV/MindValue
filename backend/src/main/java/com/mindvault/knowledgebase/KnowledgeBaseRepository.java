package com.mindvault.knowledgebase;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface KnowledgeBaseRepository extends JpaRepository<KnowledgeBase, Long> {

    List<KnowledgeBase> findByUserIdOrderByUpdatedAtDesc(Long userId);

    Optional<KnowledgeBase> findByIdAndUserId(Long id, Long userId);
}
