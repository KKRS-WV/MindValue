package com.mindvault.search;

import com.mindvault.auth.CurrentUser;
import com.mindvault.document.Document;
import com.mindvault.document.DocumentRepository;
import com.mindvault.node.KnowledgeNode;
import com.mindvault.node.KnowledgeNodeRepository;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SearchService {

    private final KnowledgeNodeRepository nodeRepository;
    private final DocumentRepository documentRepository;

    public SearchService(KnowledgeNodeRepository nodeRepository, DocumentRepository documentRepository) {
        this.nodeRepository = nodeRepository;
        this.documentRepository = documentRepository;
    }

    @Transactional(readOnly = true)
    public List<SearchResultResponse> search(CurrentUser currentUser, String keyword) {
        String value = keyword == null ? "" : keyword.trim();
        if (value.isBlank()) {
            return List.of();
        }

        List<SearchResultResponse> results = new ArrayList<>();
        for (KnowledgeNode node : nodeRepository.findByTitleContainingIgnoreCaseOrDescriptionContainingIgnoreCase(value, value)) {
            if (node.getKnowledgeBase().getUser().getId().equals(currentUser.id())) {
                String matchedField = contains(node.getTitle(), value) ? "node.title" : "node.description";
                results.add(new SearchResultResponse(node.getId(), node.getTitle(), matchedField, snippet(node.getDescription(), node.getTitle())));
            }
        }

        for (Document document : documentRepository.findByTitleContainingIgnoreCaseOrContentContainingIgnoreCase(value, value)) {
            KnowledgeNode node = document.getNode();
            if (node.getKnowledgeBase().getUser().getId().equals(currentUser.id())) {
                String matchedField = contains(document.getTitle(), value) ? "document.title" : "document.content";
                results.add(new SearchResultResponse(node.getId(), node.getTitle(), matchedField, snippet(document.getContent(), document.getTitle())));
            }
        }

        return results.stream().limit(50).toList();
    }

    private boolean contains(String source, String keyword) {
        return source != null && source.toLowerCase().contains(keyword.toLowerCase());
    }

    private String snippet(String source, String fallback) {
        String text = source == null || source.isBlank() ? fallback : source.replace('\n', ' ').trim();
        if (text == null) {
            return "";
        }
        return text.length() <= 140 ? text : text.substring(0, 140) + "...";
    }
}
