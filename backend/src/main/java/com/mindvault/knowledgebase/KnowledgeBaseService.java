package com.mindvault.knowledgebase;

import com.mindvault.auth.CurrentUser;
import com.mindvault.node.KnowledgeNode;
import com.mindvault.node.KnowledgeNodeRepository;
import com.mindvault.user.User;
import com.mindvault.user.UserRepository;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class KnowledgeBaseService {

    private final KnowledgeBaseRepository knowledgeBaseRepository;
    private final KnowledgeNodeRepository nodeRepository;
    private final UserRepository userRepository;

    public KnowledgeBaseService(
        KnowledgeBaseRepository knowledgeBaseRepository,
        KnowledgeNodeRepository nodeRepository,
        UserRepository userRepository
    ) {
        this.knowledgeBaseRepository = knowledgeBaseRepository;
        this.nodeRepository = nodeRepository;
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public List<KnowledgeBaseResponse> list(CurrentUser currentUser) {
        return knowledgeBaseRepository.findByUserIdOrderByUpdatedAtDesc(currentUser.id()).stream()
            .map(this::toResponse)
            .toList();
    }

    @Transactional
    public KnowledgeBaseResponse create(CurrentUser currentUser, KnowledgeBaseRequest request) {
        User user = userRepository.findById(currentUser.id())
            .orElseThrow(() -> new IllegalStateException("User not found."));

        KnowledgeBase knowledgeBase = new KnowledgeBase();
        knowledgeBase.setUser(user);
        knowledgeBase.setName(request.name());
        knowledgeBase.setDescription(request.description());
        knowledgeBase.setIcon(request.icon());
        knowledgeBase = knowledgeBaseRepository.save(knowledgeBase);
        seedDefaultGraph(knowledgeBase);
        return toResponse(knowledgeBase);
    }

    @Transactional
    public KnowledgeBaseResponse update(CurrentUser currentUser, Long id, KnowledgeBaseRequest request) {
        KnowledgeBase knowledgeBase = getOwned(id, currentUser.id());
        knowledgeBase.setName(request.name());
        knowledgeBase.setDescription(request.description());
        knowledgeBase.setIcon(request.icon());
        return toResponse(knowledgeBase);
    }

    @Transactional
    public void delete(CurrentUser currentUser, Long id) {
        knowledgeBaseRepository.delete(getOwned(id, currentUser.id()));
    }

    @Transactional(readOnly = true)
    public KnowledgeBase getOwned(Long id, Long userId) {
        return knowledgeBaseRepository.findByIdAndUserId(id, userId)
            .orElseThrow(() -> new IllegalStateException("Knowledge base not found."));
    }

    public KnowledgeBaseResponse toResponse(KnowledgeBase knowledgeBase) {
        return new KnowledgeBaseResponse(
            knowledgeBase.getId(),
            knowledgeBase.getName(),
            knowledgeBase.getDescription(),
            knowledgeBase.getIcon(),
            knowledgeBase.getCreatedAt(),
            knowledgeBase.getUpdatedAt()
        );
    }

    private void seedDefaultGraph(KnowledgeBase knowledgeBase) {
        KnowledgeNode root = new KnowledgeNode();
        root.setKnowledgeBase(knowledgeBase);
        root.setTitle(knowledgeBase.getName());
        root.setDescription(knowledgeBase.getDescription());
        root = nodeRepository.save(root);

        createChild(knowledgeBase, root, "Prompt");
        createChild(knowledgeBase, root, "RAG");
        createChild(knowledgeBase, root, "Agent");
        createChild(knowledgeBase, root, "LangChain");
    }

    private void createChild(KnowledgeBase knowledgeBase, KnowledgeNode parent, String title) {
        KnowledgeNode child = new KnowledgeNode();
        child.setKnowledgeBase(knowledgeBase);
        child.setParent(parent);
        child.setTitle(title);
        child.setDescription(title + " notes");
        nodeRepository.save(child);
    }
}
