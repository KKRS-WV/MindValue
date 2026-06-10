import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'repositories.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final knowledgeBaseRepositoryProvider = Provider<KnowledgeBaseRepository>((ref) {
  return KnowledgeBaseRepository(ref.watch(apiClientProvider));
});

final nodeRepositoryProvider = Provider<NodeRepository>((ref) {
  return NodeRepository(ref.watch(apiClientProvider));
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(ref.watch(apiClientProvider));
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(apiClientProvider));
});
