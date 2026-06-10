package com.mindvault.search;

import com.mindvault.auth.CurrentUser;
import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/search")
public class SearchController {

    private final SearchService searchService;

    public SearchController(SearchService searchService) {
        this.searchService = searchService;
    }

    @GetMapping
    List<SearchResultResponse> search(
        @AuthenticationPrincipal CurrentUser currentUser,
        @RequestParam(defaultValue = "") String keyword
    ) {
        return searchService.search(currentUser, keyword);
    }
}
