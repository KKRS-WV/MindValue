package com.mindvault.document;

import com.mindvault.auth.CurrentUser;
import com.mindvault.node.KnowledgeNode;
import com.mindvault.node.NodeService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DocumentService {

    private final DocumentRepository documentRepository;
    private final NodeService nodeService;

    public DocumentService(DocumentRepository documentRepository, NodeService nodeService) {
        this.documentRepository = documentRepository;
        this.nodeService = nodeService;
    }

    @Transactional(readOnly = true)
    public DocumentResponse getByNode(CurrentUser currentUser, Long nodeId) {
        nodeService.getOwned(nodeId, currentUser.id());
        return documentRepository.findByNodeIdAndNodeKnowledgeBaseUserId(nodeId, currentUser.id())
            .map(this::toResponse)
            .orElseGet(() -> new DocumentResponse(null, nodeId, "Untitled", "", null, null));
    }

    @Transactional
    public DocumentResponse create(CurrentUser currentUser, DocumentRequest request) {
        KnowledgeNode node = nodeService.getOwned(request.nodeId(), currentUser.id());
        if (documentRepository.findByNodeId(node.getId()).isPresent()) {
            throw new IllegalArgumentException("Document already exists for this node.");
        }

        Document document = new Document();
        document.setNode(node);
        document.setTitle(request.title());
        document.setContent(request.content());
        return toResponse(documentRepository.save(document));
    }

    @Transactional
    public DocumentResponse update(CurrentUser currentUser, Long id, DocumentRequest request) {
        Document document = documentRepository.findByIdAndNodeKnowledgeBaseUserId(id, currentUser.id())
            .orElseThrow(() -> new IllegalStateException("Document not found."));
        KnowledgeNode node = nodeService.getOwned(request.nodeId(), currentUser.id());
        if (!document.getNode().getId().equals(node.getId())) {
            throw new IllegalArgumentException("Document cannot move to another node in V1.");
        }

        document.setTitle(request.title());
        document.setContent(request.content());
        return toResponse(document);
    }

    @Transactional
    public void delete(CurrentUser currentUser, Long id) {
        Document document = documentRepository.findByIdAndNodeKnowledgeBaseUserId(id, currentUser.id())
            .orElseThrow(() -> new IllegalStateException("Document not found."));
        documentRepository.delete(document);
    }

    public DocumentResponse toResponse(Document document) {
        return new DocumentResponse(
            document.getId(),
            document.getNode().getId(),
            document.getTitle(),
            document.getContent(),
            document.getCreatedAt(),
            document.getUpdatedAt()
        );
    }
}
