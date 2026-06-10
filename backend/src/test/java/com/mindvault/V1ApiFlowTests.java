package com.mindvault;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class V1ApiFlowTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void supportsRegisterKnowledgeBaseGraphDocumentAndSearchFlow() throws Exception {
        String token = registerAndGetToken();

        JsonNode profile = performJson(put("/api/auth/me")
            .header("Authorization", "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(Map.of(
                "username", "Demo Writer",
                "email", "demo-writer@example.com",
                "avatar", "https://example.com/avatar.png"
            ))), status().isOk());

        assertThat(profile.get("username").asText()).isEqualTo("Demo Writer");
        assertThat(profile.get("email").asText()).isEqualTo("demo-writer@example.com");

        JsonNode knowledgeBase = performJson(post("/api/knowledge-bases")
            .header("Authorization", "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(Map.of(
                "name", "AI",
                "description", "Prompt, RAG, Agent, LangChain",
                "icon", "hub"
            ))), status().isCreated());

        long knowledgeBaseId = knowledgeBase.get("id").asLong();
        JsonNode nodes = performJson(get("/api/nodes/" + knowledgeBaseId)
            .header("Authorization", "Bearer " + token), status().isOk());

        assertThat(nodes).hasSize(5);
        long ragNodeId = findNodeId(nodes, "RAG");

        performJson(post("/api/documents")
            .header("Authorization", "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(Map.of(
                "nodeId", ragNodeId,
                "title", "RAG Notes",
                "content", "# RAG\n\nChunking, embedding, and retrieval."
            ))), status().isCreated());

        JsonNode searchResults = performJson(get("/api/search?keyword=Chunking")
            .header("Authorization", "Bearer " + token), status().isOk());

        assertThat(searchResults).hasSize(1);
        assertThat(searchResults.get(0).get("nodeId").asLong()).isEqualTo(ragNodeId);
    }

    private String registerAndGetToken() throws Exception {
        JsonNode auth = performJson(post("/api/auth/register")
            .contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(Map.of(
                "username", "Demo User",
                "email", "demo-flow@example.com",
                "password", "password123"
            ))), status().isOk());
        return auth.get("token").asText();
    }

    private JsonNode performJson(
        org.springframework.test.web.servlet.RequestBuilder request,
        org.springframework.test.web.servlet.ResultMatcher matcher
    ) throws Exception {
        String content = mockMvc.perform(request)
            .andExpect(matcher)
            .andReturn()
            .getResponse()
            .getContentAsString();
        return objectMapper.readTree(content);
    }

    private long findNodeId(JsonNode nodes, String title) {
        for (JsonNode node : nodes) {
            if (title.equals(node.get("title").asText())) {
                return node.get("id").asLong();
            }
        }
        throw new AssertionError("Node not found: " + title);
    }
}
