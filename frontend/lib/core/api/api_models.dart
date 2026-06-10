class AuthResponse {
  const AuthResponse({required this.token, required this.message});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String?,
      message: json['message'] as String? ?? '',
    );
  }

  final String? token;
  final String message;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.avatar,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      avatar: json['avatar'] as String?,
    );
  }

  final int id;
  final String username;
  final String email;
  final String? avatar;
}

class KnowledgeBase {
  const KnowledgeBase({
    required this.id,
    required this.name,
    this.description,
    this.icon,
  });

  factory KnowledgeBase.fromJson(Map<String, dynamic> json) {
    return KnowledgeBase(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
    );
  }

  final int id;
  final String name;
  final String? description;
  final String? icon;
}

class KnowledgeNode {
  const KnowledgeNode({
    required this.id,
    required this.knowledgeBaseId,
    required this.title,
    this.parentId,
    this.description,
    this.positionX,
    this.positionY,
  });

  factory KnowledgeNode.fromJson(Map<String, dynamic> json) {
    return KnowledgeNode(
      id: json['id'] as int,
      knowledgeBaseId: json['knowledgeBaseId'] as int,
      parentId: json['parentId'] as int?,
      title: json['title'] as String,
      description: json['description'] as String?,
      positionX: (json['positionX'] as num?)?.toDouble(),
      positionY: (json['positionY'] as num?)?.toDouble(),
    );
  }

  final int id;
  final int knowledgeBaseId;
  final int? parentId;
  final String title;
  final String? description;
  final double? positionX;
  final double? positionY;

  KnowledgeNode copyWith({
    int? id,
    int? knowledgeBaseId,
    int? parentId,
    String? title,
    String? description,
    double? positionX,
    double? positionY,
  }) {
    return KnowledgeNode(
      id: id ?? this.id,
      knowledgeBaseId: knowledgeBaseId ?? this.knowledgeBaseId,
      parentId: parentId ?? this.parentId,
      title: title ?? this.title,
      description: description ?? this.description,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
    );
  }
}

class MindDocument {
  const MindDocument({
    required this.nodeId,
    required this.title,
    required this.content,
    this.id,
    this.updatedAt,
  });

  factory MindDocument.fromJson(Map<String, dynamic> json) {
    return MindDocument(
      id: json['id'] as int?,
      nodeId: json['nodeId'] as int,
      title: json['title'] as String? ?? 'Untitled',
      content: json['content'] as String? ?? '',
      updatedAt: json['updatedAt'] as String?,
    );
  }

  final int? id;
  final int nodeId;
  final String title;
  final String content;
  final String? updatedAt;
}

class SearchResult {
  const SearchResult({
    required this.nodeId,
    required this.nodeTitle,
    required this.matchedField,
    required this.snippet,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      nodeId: json['nodeId'] as int,
      nodeTitle: json['nodeTitle'] as String,
      matchedField: json['matchedField'] as String,
      snippet: json['snippet'] as String,
    );
  }

  final int nodeId;
  final String nodeTitle;
  final String matchedField;
  final String snippet;
}
