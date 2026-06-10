package com.mindvault.node;

import com.mindvault.auth.CurrentUser;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/nodes")
public class NodeController {

    private final NodeService nodeService;

    public NodeController(NodeService nodeService) {
        this.nodeService = nodeService;
    }

    @GetMapping("/{knowledgeBaseId}")
    List<NodeResponse> list(@AuthenticationPrincipal CurrentUser currentUser, @PathVariable Long knowledgeBaseId) {
        return nodeService.list(currentUser, knowledgeBaseId);
    }

    @PostMapping
    ResponseEntity<NodeResponse> create(
        @AuthenticationPrincipal CurrentUser currentUser,
        @Valid @RequestBody NodeRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED).body(nodeService.create(currentUser, request));
    }

    @PutMapping("/{id}")
    ResponseEntity<NodeResponse> update(
        @AuthenticationPrincipal CurrentUser currentUser,
        @PathVariable Long id,
        @Valid @RequestBody NodeRequest request
    ) {
        return ResponseEntity.ok(nodeService.update(currentUser, id, request));
    }

    @DeleteMapping("/{id}")
    ResponseEntity<Void> delete(@AuthenticationPrincipal CurrentUser currentUser, @PathVariable Long id) {
        nodeService.delete(currentUser, id);
        return ResponseEntity.noContent().build();
    }
}
