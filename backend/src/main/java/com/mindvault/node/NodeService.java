package com.mindvault.node;

import com.mindvault.auth.CurrentUser;
import com.mindvault.knowledgebase.KnowledgeBase;
import com.mindvault.knowledgebase.KnowledgeBaseService;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class NodeService {

    private final KnowledgeNodeRepository nodeRepository;
    private final KnowledgeBaseService knowledgeBaseService;

    public NodeService(KnowledgeNodeRepository nodeRepository, KnowledgeBaseService knowledgeBaseService) {
        this.nodeRepository = nodeRepository;
        this.knowledgeBaseService = knowledgeBaseService;
    }

    @Transactional(readOnly = true)
    public List<NodeResponse> list(CurrentUser currentUser, Long knowledgeBaseId) {
        knowledgeBaseService.getOwned(knowledgeBaseId, currentUser.id());
        return nodeRepository.findByKnowledgeBaseId(knowledgeBaseId).stream()
            .map(this::toResponse)
            .toList();
    }

    @Transactional
    public NodeResponse create(CurrentUser currentUser, NodeRequest request) {
        KnowledgeBase knowledgeBase = knowledgeBaseService.getOwned(request.knowledgeBaseId(), currentUser.id());
        KnowledgeNode parent = null;
        if (request.parentId() != null) {
            parent = getOwned(request.parentId(), currentUser.id());
            if (!parent.getKnowledgeBase().getId().equals(knowledgeBase.getId())) {
                throw new IllegalArgumentException("Parent node must belong to the same knowledge base.");
            }
        }

        KnowledgeNode node = new KnowledgeNode();
        node.setKnowledgeBase(knowledgeBase);
        node.setParent(parent);
        apply(request, node);
        return toResponse(nodeRepository.save(node));
    }

    @Transactional
    public NodeResponse update(CurrentUser currentUser, Long id, NodeRequest request) {
        KnowledgeNode node = getOwned(id, currentUser.id());
        KnowledgeBase knowledgeBase = knowledgeBaseService.getOwned(request.knowledgeBaseId(), currentUser.id());
        if (!node.getKnowledgeBase().getId().equals(knowledgeBase.getId())) {
            throw new IllegalArgumentException("Node cannot move to another knowledge base in V1.");
        }

        KnowledgeNode parent = null;
        if (request.parentId() != null) {
            if (request.parentId().equals(id)) {
                throw new IllegalArgumentException("A node cannot be its own parent.");
            }
            parent = getOwned(request.parentId(), currentUser.id());
            if (!parent.getKnowledgeBase().getId().equals(knowledgeBase.getId())) {
                throw new IllegalArgumentException("Parent node must belong to the same knowledge base.");
            }
        }

        node.setParent(parent);
        apply(request, node);
        return toResponse(node);
    }

    @Transactional
    public void delete(CurrentUser currentUser, Long id) {
        nodeRepository.delete(getOwned(id, currentUser.id()));
    }

    @Transactional(readOnly = true)
    public KnowledgeNode getOwned(Long id, Long userId) {
        return nodeRepository.findByIdAndKnowledgeBaseUserId(id, userId)
            .orElseThrow(() -> new IllegalStateException("Node not found."));
    }

    public NodeResponse toResponse(KnowledgeNode node) {
        Long parentId = node.getParent() == null ? null : node.getParent().getId();
        return new NodeResponse(
            node.getId(),
            node.getKnowledgeBase().getId(),
            parentId,
            node.getTitle(),
            node.getDescription(),
            node.getPositionX(),
            node.getPositionY(),
            node.getCreatedAt(),
            node.getUpdatedAt()
        );
    }

    private void apply(NodeRequest request, KnowledgeNode node) {
        node.setTitle(request.title());
        node.setDescription(request.description());
        node.setPositionX(request.positionX());
        node.setPositionY(request.positionY());
    }
}
