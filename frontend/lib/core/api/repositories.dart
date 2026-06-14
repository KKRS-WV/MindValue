import 'api_client.dart';
import 'api_models.dart';

class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthResponse> register(String username, String email, String password) async {
    final response = await _apiClient.dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
    });
    return AuthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthResponse> login(String email, String password) async {
    final response = await _apiClient.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return AuthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserProfile> me() async {
    final response = await _apiClient.dio.get('/auth/me');
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserProfile> updateProfile({
    required String username,
    required String email,
    String? avatar,
  }) async {
    final response = await _apiClient.dio.put('/auth/me', data: {
      'username': username,
      'email': email,
      'avatar': avatar,
    });
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }
}

class KnowledgeBaseRepository {
  KnowledgeBaseRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<KnowledgeBase>> list() async {
    final response = await _apiClient.dio.get('/knowledge-bases');
    final items = response.data as List<dynamic>;
    return items.map((item) => KnowledgeBase.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<KnowledgeBase> create(String name, String description) async {
    final response = await _apiClient.dio.post('/knowledge-bases', data: {
      'name': name,
      'description': description,
      'icon': 'hub',
    });
    return KnowledgeBase.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _apiClient.dio.delete('/knowledge-bases/$id');
  }
}

class NodeRepository {
  NodeRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<KnowledgeNode>> list(int knowledgeBaseId) async {
    final response = await _apiClient.dio.get('/nodes/$knowledgeBaseId');
    final items = response.data as List<dynamic>;
    return items.map((item) => KnowledgeNode.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<KnowledgeNode> create({
    required int knowledgeBaseId,
    required String title,
    int? parentId,
    String? description,
    double? positionX,
    double? positionY,
  }) async {
    final response = await _apiClient.dio.post('/nodes', data: {
      'knowledgeBaseId': knowledgeBaseId,
      'parentId': parentId,
      'title': title,
      'description': description,
      'positionX': positionX,
      'positionY': positionY,
    });
    return KnowledgeNode.fromJson(response.data as Map<String, dynamic>);
  }

  Future<KnowledgeNode> update(
    KnowledgeNode node, {
    String? title,
    double? positionX,
    double? positionY,
  }) async {
    final response = await _apiClient.dio.put('/nodes/${node.id}', data: {
      'knowledgeBaseId': node.knowledgeBaseId,
      'parentId': node.parentId,
      'title': title ?? node.title,
      'description': node.description,
      'positionX': positionX ?? node.positionX,
      'positionY': positionY ?? node.positionY,
    });
    return KnowledgeNode.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _apiClient.dio.delete('/nodes/$id');
  }
}

class DocumentRepository {
  DocumentRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<MindDocument> getByNode(int nodeId) async {
    final response = await _apiClient.dio.get('/documents/$nodeId');
    return MindDocument.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MindDocument> save(MindDocument document) async {
    final data = {
      'nodeId': document.nodeId,
      'title': document.title,
      'content': document.content,
    };
    final response = document.id == null
        ? await _apiClient.dio.post('/documents', data: data)
        : await _apiClient.dio.put('/documents/${document.id}', data: data);
    return MindDocument.fromJson(response.data as Map<String, dynamic>);
  }
}

class SearchRepository {
  SearchRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<SearchResult>> search(String keyword) async {
    final response = await _apiClient.dio.get('/search', queryParameters: {'keyword': keyword});
    final items = response.data as List<dynamic>;
    return items.map((item) => SearchResult.fromJson(item as Map<String, dynamic>)).toList();
  }
}
