package com.mindvault.knowledgebase;

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
@RequestMapping("/api/knowledge-bases")
public class KnowledgeBaseController {

    private final KnowledgeBaseService knowledgeBaseService;

    public KnowledgeBaseController(KnowledgeBaseService knowledgeBaseService) {
        this.knowledgeBaseService = knowledgeBaseService;
    }

    @GetMapping
    List<KnowledgeBaseResponse> list(@AuthenticationPrincipal CurrentUser currentUser) {
        return knowledgeBaseService.list(currentUser);
    }

    @PostMapping
    ResponseEntity<KnowledgeBaseResponse> create(
        @AuthenticationPrincipal CurrentUser currentUser,
        @Valid @RequestBody KnowledgeBaseRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED).body(knowledgeBaseService.create(currentUser, request));
    }

    @PutMapping("/{id}")
    ResponseEntity<KnowledgeBaseResponse> update(
        @AuthenticationPrincipal CurrentUser currentUser,
        @PathVariable Long id,
        @Valid @RequestBody KnowledgeBaseRequest request
    ) {
        return ResponseEntity.ok(knowledgeBaseService.update(currentUser, id, request));
    }

    @DeleteMapping("/{id}")
    ResponseEntity<Void> delete(@AuthenticationPrincipal CurrentUser currentUser, @PathVariable Long id) {
        knowledgeBaseService.delete(currentUser, id);
        return ResponseEntity.noContent().build();
    }
}
