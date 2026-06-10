package com.mindvault.document;

import com.mindvault.auth.CurrentUser;
import jakarta.validation.Valid;
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
@RequestMapping("/api/documents")
public class DocumentController {

    private final DocumentService documentService;

    public DocumentController(DocumentService documentService) {
        this.documentService = documentService;
    }

    @GetMapping("/{nodeId}")
    ResponseEntity<DocumentResponse> getByNode(@AuthenticationPrincipal CurrentUser currentUser, @PathVariable Long nodeId) {
        return ResponseEntity.ok(documentService.getByNode(currentUser, nodeId));
    }

    @PostMapping
    ResponseEntity<DocumentResponse> create(
        @AuthenticationPrincipal CurrentUser currentUser,
        @Valid @RequestBody DocumentRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED).body(documentService.create(currentUser, request));
    }

    @PutMapping("/{id}")
    ResponseEntity<DocumentResponse> update(
        @AuthenticationPrincipal CurrentUser currentUser,
        @PathVariable Long id,
        @Valid @RequestBody DocumentRequest request
    ) {
        return ResponseEntity.ok(documentService.update(currentUser, id, request));
    }

    @DeleteMapping("/{id}")
    ResponseEntity<Void> delete(@AuthenticationPrincipal CurrentUser currentUser, @PathVariable Long id) {
        documentService.delete(currentUser, id);
        return ResponseEntity.noContent().build();
    }
}
