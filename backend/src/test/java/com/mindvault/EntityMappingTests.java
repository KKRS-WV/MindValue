package com.mindvault;

import static org.assertj.core.api.Assertions.assertThat;

import com.mindvault.document.Document;
import com.mindvault.document.DocumentRepository;
import com.mindvault.knowledgebase.KnowledgeBase;
import com.mindvault.knowledgebase.KnowledgeBaseRepository;
import com.mindvault.node.KnowledgeNode;
import com.mindvault.node.KnowledgeNodeRepository;
import com.mindvault.user.User;
import com.mindvault.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.test.context.ActiveProfiles;

@DataJpaTest
@ActiveProfiles("test")
class EntityMappingTests {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private KnowledgeBaseRepository knowledgeBaseRepository;

    @Autowired
    private KnowledgeNodeRepository knowledgeNodeRepository;

    @Autowired
    private DocumentRepository documentRepository;

    @Test
    void mapsUserKnowledgeBaseNodeAndDocumentRelationships() {
        User user = new User();
        user.setUsername("mindvault");
        user.setEmail("mindvault@example.com");
        user.setPassword("encoded-password");
        user = userRepository.saveAndFlush(user);

        KnowledgeBase knowledgeBase = new KnowledgeBase();
        knowledgeBase.setUser(user);
        knowledgeBase.setName("AI");
        knowledgeBase.setDescription("Artificial intelligence notes");
        knowledgeBase = knowledgeBaseRepository.saveAndFlush(knowledgeBase);

        KnowledgeNode root = new KnowledgeNode();
        root.setKnowledgeBase(knowledgeBase);
        root.setTitle("AI");
        root.setPositionX(0.0);
        root.setPositionY(0.0);
        root = knowledgeNodeRepository.saveAndFlush(root);

        KnowledgeNode child = new KnowledgeNode();
        child.setKnowledgeBase(knowledgeBase);
        child.setParent(root);
        child.setTitle("RAG");
        child.setPositionX(120.0);
        child.setPositionY(80.0);
        child = knowledgeNodeRepository.saveAndFlush(child);

        Document document = new Document();
        document.setNode(child);
        document.setTitle("RAG Notes");
        document.setContent("# RAG\n\nChunking, embedding, and retrieval.");
        document = documentRepository.saveAndFlush(document);

        assertThat(knowledgeBaseRepository.findByUserIdOrderByUpdatedAtDesc(user.getId())).hasSize(1);
        assertThat(knowledgeNodeRepository.findByKnowledgeBaseId(knowledgeBase.getId())).hasSize(2);
        assertThat(documentRepository.findByNodeId(child.getId())).contains(document);
        assertThat(child.getParent().getId()).isEqualTo(root.getId());
    }
}
