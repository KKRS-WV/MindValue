import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_models.dart';
import '../../core/api/providers.dart';
import '../../core/storage/local_preferences.dart';
import '../document/document_panel.dart';
import '../graph/knowledge_graph_canvas.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  List<KnowledgeBase> _knowledgeBases = const [];
  List<KnowledgeNode> _nodes = const [];
  KnowledgeBase? _selectedKnowledgeBase;
  KnowledgeNode? _selectedNode;
  MindDocument? _document;
  final _documentPanelKey = GlobalKey<DocumentPanelState>();
  _WorkspaceView _workspaceView = _WorkspaceView.map;
  _NodePositionSaveStatus _positionSaveStatus = _NodePositionSaveStatus.idle;
  final Set<int> _collapsedGraphNodeIds = {};
  int _mapFocusRequestId = 0;
  int _positionSaveRevision = 0;
  bool _layoutLocked = false;
  bool _showRelatedOnly = false;
  bool _documentPanelOpen = true;
  bool _restoringSession = true;
  bool _loadingKnowledgeBases = true;
  bool _loadingGraph = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_restoreSessionAndPreferences);
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authTokenProvider);
    if (_restoringSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (token == null) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('MindVault', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Graph-first personal knowledge management.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: MindVaultColors.muted),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _TopNavigation(
            workspaceView: _workspaceView,
            onSearch: _search,
            onAdd: _selectedKnowledgeBase == null ? _createKnowledgeBase : () => _createChildNode(),
            onEditNode: _selectedNode == null ? null : () => _renameSelectedNode(),
            onDeleteNode: _canDeleteSelectedNode ? () => _deleteSelectedNode() : null,
            documentPanelOpen: _documentPanelOpen,
            onWorkspaceViewChanged: _setWorkspaceView,
            onToggleDocumentPanel: _toggleDocumentPanel,
            onExportJson: _selectedKnowledgeBase == null ? null : _exportKnowledgeBaseJson,
            onExportMarkdown: _selectedKnowledgeBase == null ? null : _exportKnowledgeBaseMarkdown,
            onUser: () => context.go('/profile'),
          ),
          Expanded(
            child: Row(
              children: [
                _KnowledgeBaseSidebar(
                  knowledgeBases: _knowledgeBases,
                  selectedId: _selectedKnowledgeBase?.id,
                  loading: _loadingKnowledgeBases,
                  onSelect: _selectKnowledgeBase,
                  onCreate: _createKnowledgeBase,
                  onDelete: _deleteKnowledgeBase,
                ),
                Expanded(
                  child: _WorkspaceSwitcher(
                    view: _workspaceView,
                    loading: _loadingGraph,
                    error: _error,
                    knowledgeBase: _selectedKnowledgeBase,
                    nodes: _nodes,
                    graphNodes: _visibleGraphNodes,
                    selectedNode: _selectedNode,
                    mapFocusRequestId: _mapFocusRequestId,
                    positionSaveStatus: _positionSaveStatus,
                    layoutLocked: _layoutLocked,
                    showRelatedOnly: _showRelatedOnly,
                    onNodeTap: _selectNode,
                    onNodeDoubleTap: _focusNode,
                    onNodePositionChanged: _moveNode,
                    onNodePositionCommitted: _saveNodePosition,
                    onCreateChildNode: (node) => _createChildNode(node),
                    onRenameNode: (node) => _renameSelectedNode(node),
                    onDeleteNode: (node) => _deleteSelectedNode(node),
                    onToggleLayoutLock: () => setState(() => _layoutLocked = !_layoutLocked),
                    onToggleRelatedOnly: () => setState(() => _showRelatedOnly = !_showRelatedOnly),
                    onToggleCollapseBranch: _toggleCollapseBranch,
                    onExpandAllBranches: () => setState(_collapsedGraphNodeIds.clear),
                    onOrganizeBranch: _organizeSelectedBranch,
                    onCanvasTap: () => _clearSelection(),
                    onCanvasDoubleTap: () => _clearFocus(),
                    onLocateInMap: _locateNodeInMap,
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: _documentPanelOpen ? 400 : 0,
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: _documentPanelOpen ? 1 : 0,
                      child: SizedBox(
                        width: 400,
                        child: DocumentPanel(
                          key: _documentPanelKey,
                          node: _selectedNode,
                          document: _document,
                          onSave: _saveDocument,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _canDeleteSelectedNode => _selectedNode != null && _selectedNode!.parentId != null;

  List<KnowledgeNode> get _visibleGraphNodes {
    var visible = _nodes;
    if (_showRelatedOnly && _selectedNode != null) {
      final relatedIds = _relatedNodeIds(_selectedNode!);
      visible = visible.where((node) => relatedIds.contains(node.id)).toList();
    }
    if (_collapsedGraphNodeIds.isEmpty) {
      return visible;
    }
    final hiddenIds = _hiddenCollapsedDescendantIds(visible);
    return visible.where((node) => !hiddenIds.contains(node.id)).toList();
  }

  Set<int> _relatedNodeIds(KnowledgeNode selected) {
    final byId = {for (final node in _nodes) node.id: node};
    final childrenByParent = _childrenByParent(_nodes);
    final ids = <int>{selected.id};

    var cursor = selected;
    while (cursor.parentId != null && byId[cursor.parentId] != null) {
      cursor = byId[cursor.parentId]!;
      ids.add(cursor.id);
    }

    void collectDescendants(int nodeId) {
      for (final child in childrenByParent[nodeId] ?? const <KnowledgeNode>[]) {
        if (ids.add(child.id)) {
          collectDescendants(child.id);
        }
      }
    }

    collectDescendants(selected.id);
    return ids;
  }

  Set<int> _hiddenCollapsedDescendantIds(List<KnowledgeNode> sourceNodes) {
    final childrenByParent = _childrenByParent(sourceNodes);
    final hiddenIds = <int>{};

    void collect(int nodeId) {
      for (final child in childrenByParent[nodeId] ?? const <KnowledgeNode>[]) {
        if (hiddenIds.add(child.id)) {
          collect(child.id);
        }
      }
    }

    for (final id in _collapsedGraphNodeIds) {
      collect(id);
    }
    return hiddenIds;
  }

  Map<int?, List<KnowledgeNode>> _childrenByParent(List<KnowledgeNode> sourceNodes) {
    final childrenByParent = <int?, List<KnowledgeNode>>{};
    for (final node in sourceNodes) {
      childrenByParent.putIfAbsent(node.parentId, () => []).add(node);
    }
    return childrenByParent;
  }

  Future<void> _restoreSessionAndPreferences() async {
    final token = await LocalPreferences.readAuthToken();
    final savedView = await LocalPreferences.readWorkspaceView();
    final savedDocumentPanelOpen = await LocalPreferences.readDocumentPanelOpen();
    if (!mounted) {
      return;
    }
    setState(() {
      if (token != null && token.isNotEmpty) {
        ref.read(authTokenProvider.notifier).state = token;
      }
      _workspaceView = savedView == _WorkspaceView.list.name ? _WorkspaceView.list : _WorkspaceView.map;
      _documentPanelOpen = savedDocumentPanelOpen ?? true;
      _restoringSession = false;
      _loadingKnowledgeBases = token != null && token.isNotEmpty;
    });
    if (token != null && token.isNotEmpty) {
      await _loadKnowledgeBases();
    }
  }

  void _setWorkspaceView(_WorkspaceView view) {
    setState(() => _workspaceView = view);
    LocalPreferences.saveWorkspaceView(view.name);
  }

  void _toggleDocumentPanel() {
    setState(() => _documentPanelOpen = !_documentPanelOpen);
    LocalPreferences.saveDocumentPanelOpen(_documentPanelOpen);
  }

  Future<void> _loadKnowledgeBases() async {
    setState(() {
      _loadingKnowledgeBases = true;
      _error = null;
    });
    try {
      final items = await ref.read(knowledgeBaseRepositoryProvider).list();
      if (!mounted) {
        return;
      }
      setState(() {
        _knowledgeBases = items;
        _selectedKnowledgeBase = items.isEmpty ? null : _selectedKnowledgeBase ?? items.first;
      });
      if (_selectedKnowledgeBase != null) {
        await _loadGraph(_selectedKnowledgeBase!);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load knowledge bases.');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingKnowledgeBases = false);
      }
    }
  }

  Future<void> _selectKnowledgeBase(KnowledgeBase knowledgeBase) async {
    if (_selectedKnowledgeBase?.id == knowledgeBase.id) {
      return;
    }
    if (!await _canLeaveCurrentDocument()) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedKnowledgeBase = knowledgeBase;
      _selectedNode = null;
      _document = null;
      _collapsedGraphNodeIds.clear();
      _showRelatedOnly = false;
    });
    await _loadGraph(knowledgeBase);
  }

  Future<void> _loadGraph(KnowledgeBase knowledgeBase) async {
    setState(() {
      _loadingGraph = true;
      _error = null;
    });
    try {
      final nodes = await ref.read(nodeRepositoryProvider).list(knowledgeBase.id);
      if (!mounted) {
        return;
      }
      final selected = nodes.isEmpty ? null : nodes.firstWhere((node) => node.parentId == null, orElse: () => nodes.first);
      setState(() {
        _nodes = nodes;
        _selectedNode = selected;
      });
      if (selected != null) {
        await _loadDocument(selected.id);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load graph.');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingGraph = false);
      }
    }
  }

  Future<bool> _selectNode(KnowledgeNode node) async {
    if (_selectedNode?.id == node.id) {
      return true;
    }
    if (!await _canLeaveCurrentDocument()) {
      return false;
    }
    if (!mounted) {
      return false;
    }
    setState(() {
      _selectedNode = node;
      _document = null;
    });
    await _loadDocument(node.id);
    return true;
  }

  Future<void> _focusNode(KnowledgeNode node) async {
    await _selectNode(node);
  }

  Future<void> _locateNodeInMap(KnowledgeNode node) async {
    final selected = await _selectNode(node);
    if (!selected) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _workspaceView = _WorkspaceView.map;
      _showRelatedOnly = false;
      _collapsedGraphNodeIds.removeWhere((id) => _relatedNodeIds(node).contains(id));
      _mapFocusRequestId++;
    });
  }

  void _moveNode(KnowledgeNode node, Offset position) {
    final moved = node.copyWith(positionX: position.dx, positionY: position.dy);
    setState(() {
      _nodes = [
        for (final item in _nodes)
          if (item.id == node.id) moved else item,
      ];
      if (_selectedNode?.id == node.id) {
        _selectedNode = moved;
      }
    });
  }

  Future<void> _saveNodePosition(KnowledgeNode node, Offset position) async {
    final current = _nodes.firstWhere((item) => item.id == node.id, orElse: () => node);
    _setPositionSaveStatus(_NodePositionSaveStatus.saving);
    try {
      final saved = await ref.read(nodeRepositoryProvider).update(
            current,
            positionX: position.dx,
            positionY: position.dy,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _nodes = [
          for (final item in _nodes)
            if (item.id == saved.id) saved else item,
        ];
        if (_selectedNode?.id == saved.id) {
          _selectedNode = saved;
        }
      });
      _setPositionSaveStatus(_NodePositionSaveStatus.saved, autoClear: true);
    } catch (_) {
      if (mounted) {
        _setPositionSaveStatus(_NodePositionSaveStatus.error, autoClear: true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save node position')));
      }
    }
  }

  void _setPositionSaveStatus(_NodePositionSaveStatus status, {bool autoClear = false}) {
    final revision = ++_positionSaveRevision;
    if (mounted) {
      setState(() => _positionSaveStatus = status);
    }
    if (!autoClear) {
      return;
    }
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted && _positionSaveRevision == revision) {
        setState(() => _positionSaveStatus = _NodePositionSaveStatus.idle);
      }
    });
  }

  Future<void> _clearSelection() async {
    if (!await _canLeaveCurrentDocument()) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedNode = null;
      _document = null;
    });
  }

  Future<void> _clearFocus() async {
    await _clearSelection();
  }

  Future<void> _loadDocument(int nodeId) async {
    final document = await ref.read(documentRepositoryProvider).getByNode(nodeId);
    if (mounted) {
      setState(() => _document = document);
    }
  }

  Future<void> _saveDocument(MindDocument document) async {
    final saved = await ref.read(documentRepositoryProvider).save(document);
    KnowledgeNode? updatedNode;
    final selected = _selectedNode;
    final normalizedTitle = saved.title.trim();
    if (selected != null && selected.id == saved.nodeId && normalizedTitle.isNotEmpty && selected.title != normalizedTitle) {
      updatedNode = await ref.read(nodeRepositoryProvider).update(selected, title: normalizedTitle);
    }
    if (mounted) {
      setState(() {
        _document = saved;
        if (updatedNode != null) {
          final renamedNode = updatedNode;
          _nodes = [
            for (final item in _nodes)
              if (item.id == renamedNode.id) renamedNode else item,
          ];
          _selectedNode = renamedNode;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document saved')));
    }
  }

  Future<void> _exportKnowledgeBaseJson() async {
    final knowledgeBase = _selectedKnowledgeBase;
    if (knowledgeBase == null) {
      return;
    }
    final documents = await _loadDocumentsForExport();
    final payload = {
      'knowledgeBase': {
        'id': knowledgeBase.id,
        'name': knowledgeBase.name,
        'description': knowledgeBase.description,
        'icon': knowledgeBase.icon,
      },
      'nodes': [
        for (final node in _nodes)
          {
            'id': node.id,
            'parentId': node.parentId,
            'title': node.title,
            'description': node.description,
            'positionX': node.positionX,
            'positionY': node.positionY,
            'document': documents[node.id] == null
                ? null
                : {
                    'title': documents[node.id]!.title,
                    'content': documents[node.id]!.content,
                  },
          },
      ],
    };
    const encoder = JsonEncoder.withIndent('  ');
    await Clipboard.setData(ClipboardData(text: encoder.convert(payload)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Knowledge base JSON copied')));
    }
  }

  Future<void> _exportKnowledgeBaseMarkdown() async {
    final knowledgeBase = _selectedKnowledgeBase;
    if (knowledgeBase == null) {
      return;
    }
    final documents = await _loadDocumentsForExport();
    final childrenByParent = _childrenByParent(_nodes);
    final buffer = StringBuffer()
      ..writeln('# ${knowledgeBase.name}')
      ..writeln();
    if ((knowledgeBase.description ?? '').trim().isNotEmpty) {
      buffer
        ..writeln(knowledgeBase.description!.trim())
        ..writeln();
    }

    void writeNode(KnowledgeNode node, int depth) {
      final headingDepth = (depth + 2).clamp(2, 6).toInt();
      final headingPrefix = List.filled(headingDepth, '#').join();
      buffer
        ..writeln('$headingPrefix ${node.title}')
        ..writeln();
      final description = node.description?.trim();
      if (description != null && description.isNotEmpty) {
        buffer
          ..writeln(description)
          ..writeln();
      }
      final document = documents[node.id];
      if (document != null && document.content.trim().isNotEmpty) {
        buffer
          ..writeln(document.content.trim())
          ..writeln();
      }
      for (final child in childrenByParent[node.id] ?? const <KnowledgeNode>[]) {
        writeNode(child, depth + 1);
      }
    }

    final roots = childrenByParent[null] ?? const <KnowledgeNode>[];
    for (final root in roots) {
      writeNode(root, 0);
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Knowledge base Markdown copied')));
    }
  }

  Future<Map<int, MindDocument>> _loadDocumentsForExport() async {
    final repository = ref.read(documentRepositoryProvider);
    final documents = <int, MindDocument>{};
    for (final node in _nodes) {
      try {
        documents[node.id] = await repository.getByNode(node.id);
      } catch (_) {
        if (_document?.nodeId == node.id) {
          documents[node.id] = _document!;
        }
      }
    }
    return documents;
  }

  Future<bool> _canLeaveCurrentDocument() async {
    return await _documentPanelKey.currentState?.confirmDiscardIfNeeded() ?? true;
  }

  Future<void> _createKnowledgeBase() async {
    final nameController = TextEditingController(text: 'AI');
    final descriptionController = TextEditingController(text: 'Prompt, RAG, Agent, LangChain');
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New knowledge base'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, (nameController.text, descriptionController.text)),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    nameController.dispose();
    descriptionController.dispose();
    if (result == null || result.$1.trim().isEmpty) {
      return;
    }

    final created = await ref.read(knowledgeBaseRepositoryProvider).create(result.$1.trim(), result.$2.trim());
    await _loadKnowledgeBases();
    await _selectKnowledgeBase(created);
  }

  Future<void> _createChildNode([KnowledgeNode? targetParent]) async {
    final parent = targetParent ?? _selectedNode;
    final knowledgeBase = _selectedKnowledgeBase;
    if (parent == null || knowledgeBase == null) {
      return;
    }
    final titleController = TextEditingController(text: 'New Node');
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add child node'),
        content: TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, titleController.text), child: const Text('Add')),
        ],
      ),
    );
    titleController.dispose();
    if (title == null || title.trim().isEmpty) {
      return;
    }

    final initialPosition = _initialChildPosition(parent);
    final created = await ref.read(nodeRepositoryProvider).create(
          knowledgeBaseId: knowledgeBase.id,
          parentId: parent.id,
          title: title.trim(),
          description: '${title.trim()} notes',
          positionX: initialPosition?.dx,
          positionY: initialPosition?.dy,
        );
    await _loadGraph(knowledgeBase);
    final freshNode = _nodes.firstWhere((node) => node.id == created.id, orElse: () => created);
    await _selectNode(freshNode);
  }

  Offset? _initialChildPosition(KnowledgeNode parent) {
    if (parent.positionX == null || parent.positionY == null) {
      return null;
    }
    if (parent.positionX == 0 && parent.positionY == 0) {
      return null;
    }
    final siblingCount = _nodes.where((node) => node.parentId == parent.id).length;
    final angle = -math.pi / 2 + siblingCount * 0.72;
    final ring = 170.0 + (siblingCount ~/ 8) * 56.0;
    return Offset(
      parent.positionX! + math.cos(angle) * ring,
      parent.positionY! + math.sin(angle) * ring,
    );
  }

  Future<void> _renameSelectedNode([KnowledgeNode? targetNode]) async {
    final node = targetNode ?? _selectedNode;
    final knowledgeBase = _selectedKnowledgeBase;
    if (node == null || knowledgeBase == null) {
      return;
    }
    final titleController = TextEditingController(text: node.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename node'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Node title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, titleController.text), child: const Text('Save')),
        ],
      ),
    );
    titleController.dispose();
    if (title == null || title.trim().isEmpty || title.trim() == node.title) {
      return;
    }

    final updated = await ref.read(nodeRepositoryProvider).update(node, title: title.trim());
    await _loadGraph(knowledgeBase);
    await _selectNode(updated);
  }

  Future<void> _deleteSelectedNode([KnowledgeNode? targetNode]) async {
    final node = targetNode ?? _selectedNode;
    final knowledgeBase = _selectedKnowledgeBase;
    if (node == null || knowledgeBase == null || node.parentId == null) {
      return;
    }
    final confirmed = await _confirm(
      title: 'Delete node',
      message: 'Delete "${node.title}" and its child nodes?',
      action: 'Delete',
    );
    if (!confirmed) {
      return;
    }

    await ref.read(nodeRepositoryProvider).delete(node.id);
    await _loadGraph(knowledgeBase);
  }

  void _toggleCollapseBranch(KnowledgeNode node) {
    setState(() {
      if (_collapsedGraphNodeIds.contains(node.id)) {
        _collapsedGraphNodeIds.remove(node.id);
      } else {
        _collapsedGraphNodeIds.add(node.id);
      }
    });
  }

  Future<void> _organizeSelectedBranch() async {
    final selected = _selectedNode;
    if (selected == null) {
      return;
    }

    final childrenByParent = _childrenByParent(_nodes);
    final branchNodes = <KnowledgeNode>[];

    void collect(KnowledgeNode node, int depth, Set<int> path) {
      if (path.contains(node.id)) {
        return;
      }
      branchNodes.add(node);
      for (final child in childrenByParent[node.id] ?? const <KnowledgeNode>[]) {
        collect(child, depth + 1, {...path, node.id});
      }
    }

    collect(selected, 0, const <int>{});
    if (branchNodes.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No child nodes to organize')));
      return;
    }

    for (final siblings in childrenByParent.values) {
      siblings.sort((a, b) => a.title.compareTo(b.title));
    }

    final base = _savedPositionOf(selected) ?? _averageSavedPosition(branchNodes) ?? const Offset(900, 600);
    final plannedPositions = _planRadialBranchLayout(
      root: selected,
      rootPosition: base,
      childrenByParent: childrenByParent,
    );

    setState(() {
      _nodes = [
        for (final node in _nodes) _nodeWithPlannedPosition(node, plannedPositions),
      ];
      final position = _selectedNode == null ? null : plannedPositions[_selectedNode!.id];
      if (_selectedNode != null && position != null) {
        _selectedNode = _selectedNode!.copyWith(positionX: position.dx, positionY: position.dy);
      }
    });

    _setPositionSaveStatus(_NodePositionSaveStatus.saving);
    try {
      final repository = ref.read(nodeRepositoryProvider);
      final savedNodes = <KnowledgeNode>[];
      for (final node in branchNodes) {
        final position = plannedPositions[node.id];
        if (position == null) {
          continue;
        }
        savedNodes.add(await repository.update(node, positionX: position.dx, positionY: position.dy));
      }
      if (!mounted) {
        return;
      }
      final savedById = {for (final node in savedNodes) node.id: node};
      setState(() {
        _nodes = [
          for (final node in _nodes) savedById[node.id] ?? node,
        ];
        if (_selectedNode != null && savedById[_selectedNode!.id] != null) {
          _selectedNode = savedById[_selectedNode!.id];
        }
      });
      _setPositionSaveStatus(_NodePositionSaveStatus.saved, autoClear: true);
    } catch (_) {
      if (mounted) {
        _setPositionSaveStatus(_NodePositionSaveStatus.error, autoClear: true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to organize branch')));
      }
    }
  }

  Offset? _savedPositionOf(KnowledgeNode node) {
    if (node.positionX == null || node.positionY == null) {
      return null;
    }
    if (node.positionX == 0 && node.positionY == 0) {
      return null;
    }
    return Offset(node.positionX!, node.positionY!);
  }

  KnowledgeNode _nodeWithPlannedPosition(KnowledgeNode node, Map<int, Offset> plannedPositions) {
    final position = plannedPositions[node.id];
    return position == null ? node : node.copyWith(positionX: position.dx, positionY: position.dy);
  }

  Map<int, Offset> _planRadialBranchLayout({
    required KnowledgeNode root,
    required Offset rootPosition,
    required Map<int?, List<KnowledgeNode>> childrenByParent,
  }) {
    const ringSpacing = 210.0;
    const startAngle = -math.pi / 2;
    final planned = <int, Offset>{root.id: rootPosition};
    final weights = <int, int>{};

    int measure(KnowledgeNode node, Set<int> path) {
      if (path.contains(node.id)) {
        return 1;
      }
      final children = childrenByParent[node.id] ?? const <KnowledgeNode>[];
      if (children.isEmpty) {
        weights[node.id] = 1;
        return 1;
      }
      final nextPath = {...path, node.id};
      final weight = children.fold<int>(0, (total, child) => total + measure(child, nextPath));
      weights[node.id] = math.max(1, weight);
      return weights[node.id]!;
    }

    void placeChildren(KnowledgeNode parent, int depth, double sectorStart, double sectorEnd, Set<int> path) {
      if (path.contains(parent.id)) {
        return;
      }
      final children = childrenByParent[parent.id] ?? const <KnowledgeNode>[];
      if (children.isEmpty) {
        return;
      }

      final sweep = sectorEnd - sectorStart;
      final padding = children.length <= 1 ? 0.0 : math.min(0.18, sweep.abs() * 0.10);
      final usableSweep = math.max(0.001, sweep - padding * 2);
      final totalWeight = children.fold<int>(0, (total, child) => total + (weights[child.id] ?? 1));
      var cursor = sectorStart + padding;

      for (final child in children) {
        final share = usableSweep * ((weights[child.id] ?? 1) / math.max(1, totalWeight));
        final childStart = cursor;
        final childEnd = cursor + share;
        final angle = (childStart + childEnd) / 2;
        final radius = ringSpacing * depth;
        planned[child.id] = Offset(
          rootPosition.dx + math.cos(angle) * radius,
          rootPosition.dy + math.sin(angle) * radius,
        );
        placeChildren(child, depth + 1, childStart, childEnd, {...path, parent.id});
        cursor += share;
      }
    }

    measure(root, const <int>{});
    placeChildren(root, 1, startAngle, startAngle + math.pi * 2, const <int>{});
    return planned;
  }

  Offset? _averageSavedPosition(List<KnowledgeNode> nodes) {
    var count = 0;
    var total = Offset.zero;
    for (final node in nodes) {
      final position = _savedPositionOf(node);
      if (position == null) {
        continue;
      }
      count++;
      total += position;
    }
    return count == 0 ? null : total / count.toDouble();
  }

  Future<void> _deleteKnowledgeBase(KnowledgeBase knowledgeBase) async {
    final confirmed = await _confirm(
      title: 'Delete knowledge base',
      message: 'Delete "${knowledgeBase.name}" and all nodes/documents inside it?',
      action: 'Delete',
    );
    if (!confirmed) {
      return;
    }

    await ref.read(knowledgeBaseRepositoryProvider).delete(knowledgeBase.id);
    setState(() {
      if (_selectedKnowledgeBase?.id == knowledgeBase.id) {
        _selectedKnowledgeBase = null;
        _selectedNode = null;
        _document = null;
        _nodes = const [];
      }
    });
    await _loadKnowledgeBases();
  }

  Future<bool> _confirm({required String title, required String message, required String action}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: MindVaultColors.error.withValues(alpha: 0.12),
              foregroundColor: MindVaultColors.error,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _search() async {
    final result = await showDialog<SearchResult>(
      context: context,
      builder: (context) => const _SearchDialog(),
    );
    if (result == null) {
      return;
    }
    for (final node in _nodes) {
      if (node.id == result.nodeId) {
        await _locateNodeInMap(node);
        return;
      }
    }
  }
}

enum _WorkspaceView { map, list }

enum _ExportAction { json, markdown }

enum _NodePositionSaveStatus { idle, saving, saved, error }

class _TopNavigation extends StatelessWidget {
  const _TopNavigation({
    required this.workspaceView,
    required this.onSearch,
    required this.onAdd,
    required this.onEditNode,
    required this.onDeleteNode,
    required this.documentPanelOpen,
    required this.onWorkspaceViewChanged,
    required this.onToggleDocumentPanel,
    required this.onExportJson,
    required this.onExportMarkdown,
    required this.onUser,
  });

  final _WorkspaceView workspaceView;
  final VoidCallback onSearch;
  final VoidCallback onAdd;
  final VoidCallback? onEditNode;
  final VoidCallback? onDeleteNode;
  final bool documentPanelOpen;
  final ValueChanged<_WorkspaceView> onWorkspaceViewChanged;
  final VoidCallback onToggleDocumentPanel;
  final VoidCallback? onExportJson;
  final VoidCallback? onExportMarkdown;
  final VoidCallback onUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: MindVaultColors.surface,
        border: Border(bottom: BorderSide(color: MindVaultColors.border)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 220,
            child: Text('MindVault', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 320,
            height: 38,
            child: TextField(
              readOnly: true,
              onTap: onSearch,
              decoration: InputDecoration(
                hintText: 'Search nodes, documents...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: MindVaultColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: MindVaultColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: MindVaultColors.border),
                ),
              ),
            ),
          ),
          const Spacer(),
          IconButton(tooltip: 'Search', onPressed: onSearch, icon: const Icon(Icons.search)),
          IconButton(tooltip: 'Add', onPressed: onAdd, icon: const Icon(Icons.add)),
          IconButton(tooltip: 'Rename node', onPressed: onEditNode, icon: const Icon(Icons.drive_file_rename_outline)),
          IconButton(tooltip: 'Delete node', onPressed: onDeleteNode, icon: const Icon(Icons.delete_outline)),
          IconButton(
            tooltip: documentPanelOpen ? 'Hide document panel' : 'Show document panel',
            onPressed: onToggleDocumentPanel,
            icon: Icon(documentPanelOpen ? Icons.subject_outlined : Icons.view_sidebar_outlined),
          ),
          PopupMenuButton<_ExportAction>(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share_outlined),
            onSelected: (value) {
              switch (value) {
                case _ExportAction.json:
                  onExportJson?.call();
                  break;
                case _ExportAction.markdown:
                  onExportMarkdown?.call();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _ExportAction.json,
                enabled: onExportJson != null,
                child: const Text('Copy JSON'),
              ),
              PopupMenuItem(
                value: _ExportAction.markdown,
                enabled: onExportMarkdown != null,
                child: const Text('Copy Markdown'),
              ),
            ],
          ),
          const SizedBox(width: 8),
          SegmentedButton<_WorkspaceView>(
            segments: const [
              ButtonSegment(
                value: _WorkspaceView.map,
                icon: Icon(Icons.hub_outlined, size: 18),
                label: Text('Map'),
              ),
              ButtonSegment(
                value: _WorkspaceView.list,
                icon: Icon(Icons.view_list_outlined, size: 18),
                label: Text('List'),
              ),
            ],
            selected: {workspaceView},
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10)),
            ),
            onSelectionChanged: (values) => onWorkspaceViewChanged(values.first),
          ),
          const SizedBox(width: 8),
          IconButton(tooltip: 'Settings', onPressed: () {}, icon: const Icon(Icons.settings_outlined)),
          IconButton(tooltip: 'Account', onPressed: onUser, icon: const Icon(Icons.account_circle_outlined)),
        ],
      ),
    );
  }
}

class _KnowledgeBaseSidebar extends StatelessWidget {
  const _KnowledgeBaseSidebar({
    required this.knowledgeBases,
    required this.selectedId,
    required this.loading,
    required this.onSelect,
    required this.onCreate,
    required this.onDelete,
  });

  final List<KnowledgeBase> knowledgeBases;
  final int? selectedId;
  final bool loading;
  final ValueChanged<KnowledgeBase> onSelect;
  final VoidCallback onCreate;
  final ValueChanged<KnowledgeBase> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: MindVaultColors.surface,
        border: Border(right: BorderSide(color: MindVaultColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Text('Knowledge Bases', style: TextStyle(fontSize: 14, color: MindVaultColors.muted)),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: knowledgeBases.length,
                    itemBuilder: (context, index) {
                      final item = knowledgeBases[index];
                      final selected = selectedId == item.id;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onSelect(item),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              color: selected ? MindVaultColors.selected : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.hub_outlined,
                                  size: 18,
                                  color: selected ? MindVaultColors.primary : MindVaultColors.muted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                      color: selected ? MindVaultColors.primary : MindVaultColors.text,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  IconButton(
                                    tooltip: 'Delete knowledge base',
                                    onPressed: () => onDelete(item),
                                    icon: const Icon(Icons.delete_outline, size: 17),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                                    color: MindVaultColors.muted,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Knowledge Base'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSwitcher extends StatelessWidget {
  const _WorkspaceSwitcher({
    required this.view,
    required this.loading,
    required this.error,
    required this.knowledgeBase,
    required this.nodes,
    required this.graphNodes,
    required this.selectedNode,
    required this.mapFocusRequestId,
    required this.positionSaveStatus,
    required this.layoutLocked,
    required this.showRelatedOnly,
    required this.onNodeTap,
    required this.onNodeDoubleTap,
    required this.onNodePositionChanged,
    required this.onNodePositionCommitted,
    required this.onCreateChildNode,
    required this.onRenameNode,
    required this.onDeleteNode,
    required this.onToggleLayoutLock,
    required this.onToggleRelatedOnly,
    required this.onToggleCollapseBranch,
    required this.onExpandAllBranches,
    required this.onOrganizeBranch,
    required this.onCanvasTap,
    required this.onCanvasDoubleTap,
    required this.onLocateInMap,
  });

  final _WorkspaceView view;
  final bool loading;
  final String? error;
  final KnowledgeBase? knowledgeBase;
  final List<KnowledgeNode> nodes;
  final List<KnowledgeNode> graphNodes;
  final KnowledgeNode? selectedNode;
  final int mapFocusRequestId;
  final _NodePositionSaveStatus positionSaveStatus;
  final bool layoutLocked;
  final bool showRelatedOnly;
  final ValueChanged<KnowledgeNode> onNodeTap;
  final ValueChanged<KnowledgeNode> onNodeDoubleTap;
  final void Function(KnowledgeNode node, Offset position) onNodePositionChanged;
  final void Function(KnowledgeNode node, Offset position) onNodePositionCommitted;
  final ValueChanged<KnowledgeNode> onCreateChildNode;
  final ValueChanged<KnowledgeNode> onRenameNode;
  final ValueChanged<KnowledgeNode> onDeleteNode;
  final VoidCallback onToggleLayoutLock;
  final VoidCallback onToggleRelatedOnly;
  final ValueChanged<KnowledgeNode> onToggleCollapseBranch;
  final VoidCallback onExpandAllBranches;
  final VoidCallback onOrganizeBranch;
  final VoidCallback onCanvasTap;
  final VoidCallback onCanvasDoubleTap;
  final ValueChanged<KnowledgeNode> onLocateInMap;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: view == _WorkspaceView.map
          ? _GraphWorkspace(
              key: const ValueKey('map-workspace'),
              loading: loading,
              error: error,
              knowledgeBase: knowledgeBase,
              nodes: graphNodes,
              selectedNode: selectedNode,
              mapFocusRequestId: mapFocusRequestId,
              positionSaveStatus: positionSaveStatus,
              layoutLocked: layoutLocked,
              showRelatedOnly: showRelatedOnly,
              onNodeTap: onNodeTap,
              onNodeDoubleTap: onNodeDoubleTap,
              onNodePositionChanged: onNodePositionChanged,
              onNodePositionCommitted: onNodePositionCommitted,
              onCreateChildNode: onCreateChildNode,
              onRenameNode: onRenameNode,
              onDeleteNode: onDeleteNode,
              onToggleLayoutLock: onToggleLayoutLock,
              onToggleRelatedOnly: onToggleRelatedOnly,
              onToggleCollapseBranch: onToggleCollapseBranch,
              onExpandAllBranches: onExpandAllBranches,
              onOrganizeBranch: onOrganizeBranch,
              onCanvasTap: onCanvasTap,
              onCanvasDoubleTap: onCanvasDoubleTap,
            )
          : _TraditionalWorkspace(
              key: const ValueKey('list-workspace'),
              loading: loading,
              error: error,
              knowledgeBase: knowledgeBase,
              nodes: nodes,
              selectedNode: selectedNode,
              onNodeTap: onNodeTap,
              onLocateInMap: onLocateInMap,
            ),
    );
  }
}

class _TraditionalWorkspace extends StatefulWidget {
  const _TraditionalWorkspace({
    required this.loading,
    required this.error,
    required this.knowledgeBase,
    required this.nodes,
    required this.selectedNode,
    required this.onNodeTap,
    required this.onLocateInMap,
    super.key,
  });

  final bool loading;
  final String? error;
  final KnowledgeBase? knowledgeBase;
  final List<KnowledgeNode> nodes;
  final KnowledgeNode? selectedNode;
  final ValueChanged<KnowledgeNode> onNodeTap;
  final ValueChanged<KnowledgeNode> onLocateInMap;

  @override
  State<_TraditionalWorkspace> createState() => _TraditionalWorkspaceState();
}

class _TraditionalWorkspaceState extends State<_TraditionalWorkspace> {
  final _searchController = TextEditingController();
  final Map<int, GlobalKey> _rowKeys = {};
  final Set<int> _expandedNodeIds = {};
  bool _knowledgeBaseExpanded = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _expandAncestorsOfSelected();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollSelectedIntoView());
  }

  @override
  void didUpdateWidget(covariant _TraditionalWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.knowledgeBase?.id != widget.knowledgeBase?.id) {
      _expandedNodeIds.clear();
      _knowledgeBaseExpanded = true;
      _searchController.clear();
      _rowKeys.clear();
      _expandAncestorsOfSelected();
    }
    if (oldWidget.selectedNode?.id != widget.selectedNode?.id) {
      _expandAncestorsOfSelected();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollSelectedIntoView());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tree = _buildTree();
    final query = _searchController.text.trim().toLowerCase();
    final includedIds = query.isEmpty ? null : _filterIncludedNodeIds(query);
    final flattenedNodes = _flattenNodes(
      tree.childrenByParent,
      includedIds: includedIds,
      forceExpanded: query.isNotEmpty,
    );
    return Container(
      color: MindVaultColors.background,
      child: widget.loading
          ? const Center(child: CircularProgressIndicator())
          : widget.error != null
              ? Center(child: Text(widget.error!))
              : widget.knowledgeBase == null
                  ? const Center(child: Text('Create or select a knowledge base'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(48, 34, 48, 56),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: MindVaultColors.selected,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.library_books_outlined, color: MindVaultColors.primary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.knowledgeBase!.name,
                                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.knowledgeBase!.description ?? 'Knowledge nodes and markdown documents',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: MindVaultColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                const Text('Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                SizedBox(
                                  width: 260,
                                  height: 38,
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'Filter list...',
                                      prefixIcon: const Icon(Icons.search, size: 18),
                                      suffixIcon: query.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: 'Clear',
                                              onPressed: _searchController.clear,
                                              icon: const Icon(Icons.close, size: 16),
                                            ),
                                      filled: true,
                                      fillColor: MindVaultColors.surface,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: MindVaultColors.border),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: MindVaultColors.border),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: MindVaultColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: MindVaultColors.border),
                              ),
                              child: !_knowledgeBaseExpanded
                                  ? _KnowledgeBaseTreeHeader(
                                      knowledgeBase: widget.knowledgeBase!,
                                      expanded: false,
                                      onToggle: () => setState(() => _knowledgeBaseExpanded = true),
                                    )
                                  : Column(
                                      children: [
                                        _KnowledgeBaseTreeHeader(
                                          knowledgeBase: widget.knowledgeBase!,
                                          expanded: true,
                                          onToggle: () => setState(() => _knowledgeBaseExpanded = false),
                                        ),
                                        if (flattenedNodes.isEmpty)
                                          Padding(
                                            padding: const EdgeInsets.all(28),
                                            child: Text(
                                              query.isEmpty ? 'No nodes yet.' : 'No matching nodes.',
                                              style: const TextStyle(color: MindVaultColors.muted),
                                            ),
                                          )
                                        else
                                          ...flattenedNodes.map((item) {
                                            final selected = widget.selectedNode?.id == item.node.id;
                                            final isLast = item == flattenedNodes.last;
                                            return _TraditionalNodeRow(
                                              key: _rowKeyFor(item.node.id),
                                              item: item,
                                              selected: selected,
                                              last: isLast,
                                              expanded: _expandedNodeIds.contains(item.node.id),
                                              onToggleExpanded: item.hasChildren ? () => _toggleNode(item.node.id) : null,
                                              onTap: () => widget.onNodeTap(item.node),
                                              onLocateInMap: () => widget.onLocateInMap(item.node),
                                            );
                                          }),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  _TraditionalTree _buildTree() {
    final childrenByParent = <int?, List<KnowledgeNode>>{};
    for (final node in widget.nodes) {
      childrenByParent.putIfAbsent(node.parentId, () => []).add(node);
    }
    for (final siblings in childrenByParent.values) {
      siblings.sort((a, b) => a.title.compareTo(b.title));
    }
    return _TraditionalTree(childrenByParent: childrenByParent);
  }

  List<_TraditionalNodeItem> _flattenNodes(
    Map<int?, List<KnowledgeNode>> childrenByParent, {
    Set<int>? includedIds,
    bool forceExpanded = false,
  }) {
    final result = <_TraditionalNodeItem>[];
    void walk(KnowledgeNode node, int depth, Set<int> path) {
      if (path.contains(node.id)) {
        return;
      }
      if (includedIds != null && !includedIds.contains(node.id)) {
        return;
      }
      final children = childrenByParent[node.id] ?? const <KnowledgeNode>[];
      final hasChildren = children.isNotEmpty;
      result.add(_TraditionalNodeItem(node: node, depth: depth, hasChildren: hasChildren));
      if (!forceExpanded && hasChildren && !_expandedNodeIds.contains(node.id)) {
        return;
      }
      for (final child in children) {
        walk(child, depth + 1, {...path, node.id});
      }
    }

    final roots = childrenByParent[null] ?? const <KnowledgeNode>[];
    if (roots.isEmpty && widget.nodes.isNotEmpty) {
      for (final node in widget.nodes) {
        walk(node, 0, const <int>{});
      }
      return result;
    }
    for (final root in roots) {
      walk(root, 0, const <int>{});
    }
    return result;
  }

  Set<int> _filterIncludedNodeIds(String query) {
    final byId = {for (final node in widget.nodes) node.id: node};
    final included = <int>{};

    bool matches(KnowledgeNode node) {
      final description = node.description ?? '';
      return node.title.toLowerCase().contains(query) || description.toLowerCase().contains(query);
    }

    for (final node in widget.nodes) {
      if (!matches(node)) {
        continue;
      }
      included.add(node.id);
      var cursor = node;
      while (cursor.parentId != null && byId[cursor.parentId] != null) {
        cursor = byId[cursor.parentId]!;
        included.add(cursor.id);
      }
    }
    return included;
  }

  GlobalKey _rowKeyFor(int nodeId) {
    return _rowKeys.putIfAbsent(nodeId, () => GlobalObjectKey('traditional-node-$nodeId'));
  }

  void _scrollSelectedIntoView() {
    final selectedId = widget.selectedNode?.id;
    if (selectedId == null) {
      return;
    }
    final context = _rowKeys[selectedId]?.currentContext;
    if (context == null) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 0.42,
    );
  }

  void _toggleNode(int id) {
    setState(() {
      if (_expandedNodeIds.contains(id)) {
        _expandedNodeIds.remove(id);
      } else {
        _expandedNodeIds.add(id);
      }
    });
  }

  void _expandAncestorsOfSelected() {
    final selected = widget.selectedNode;
    if (selected == null) {
      return;
    }
    final byId = {for (final node in widget.nodes) node.id: node};
    var cursor = selected;
    while (cursor.parentId != null && byId[cursor.parentId] != null) {
      cursor = byId[cursor.parentId]!;
      _expandedNodeIds.add(cursor.id);
    }
  }
}

class _TraditionalTree {
  const _TraditionalTree({required this.childrenByParent});

  final Map<int?, List<KnowledgeNode>> childrenByParent;
}

class _TraditionalNodeItem {
  const _TraditionalNodeItem({required this.node, required this.depth, required this.hasChildren});

  final KnowledgeNode node;
  final int depth;
  final bool hasChildren;
}

class _KnowledgeBaseTreeHeader extends StatelessWidget {
  const _KnowledgeBaseTreeHeader({
    required this.knowledgeBase,
    required this.expanded,
    required this.onToggle,
  });

  final KnowledgeBase knowledgeBase;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(
          color: Color(0xFFFAFAFA),
          border: Border(bottom: BorderSide(color: MindVaultColors.border)),
        ),
        child: Row(
          children: [
            Icon(expanded ? Icons.keyboard_arrow_down : Icons.chevron_right, color: MindVaultColors.muted),
            const SizedBox(width: 8),
            const Icon(Icons.library_books_outlined, size: 18, color: MindVaultColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                knowledgeBase.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TraditionalNodeRow extends StatelessWidget {
  const _TraditionalNodeRow({
    required this.item,
    required this.selected,
    required this.last,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onTap,
    required this.onLocateInMap,
    super.key,
  });

  final _TraditionalNodeItem item;
  final bool selected;
  final bool last;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final VoidCallback onTap;
  final VoidCallback onLocateInMap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          onDoubleTap: onLocateInMap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 52),
            padding: EdgeInsets.fromLTRB(18 + item.depth * 24, 8, 10, 8),
            color: selected ? MindVaultColors.selected : MindVaultColors.surface,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: onToggleExpanded == null
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: expanded ? 'Collapse' : 'Expand',
                          onPressed: onToggleExpanded,
                          icon: Icon(expanded ? Icons.keyboard_arrow_down : Icons.chevron_right, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                        ),
                ),
                const SizedBox(width: 2),
                Icon(
                  item.depth == 0 ? Icons.hub_outlined : Icons.article_outlined,
                  size: 18,
                  color: selected ? MindVaultColors.primary : MindVaultColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.node.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected ? MindVaultColors.primary : MindVaultColors.text,
                        ),
                      ),
                      if (item.node.description != null && item.node.description!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.node.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: MindVaultColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Locate in map',
                  onPressed: onLocateInMap,
                  icon: const Icon(Icons.near_me_outlined, size: 18),
                ),
              ],
            ),
          ),
        ),
        if (!last) const Divider(height: 1),
      ],
    );
  }
}

class _GraphWorkspace extends StatelessWidget {
  const _GraphWorkspace({
    required this.loading,
    required this.error,
    required this.knowledgeBase,
    required this.nodes,
    required this.selectedNode,
    required this.mapFocusRequestId,
    required this.positionSaveStatus,
    required this.layoutLocked,
    required this.showRelatedOnly,
    required this.onNodeTap,
    required this.onNodeDoubleTap,
    required this.onNodePositionChanged,
    required this.onNodePositionCommitted,
    required this.onCreateChildNode,
    required this.onRenameNode,
    required this.onDeleteNode,
    required this.onToggleLayoutLock,
    required this.onToggleRelatedOnly,
    required this.onToggleCollapseBranch,
    required this.onExpandAllBranches,
    required this.onOrganizeBranch,
    required this.onCanvasTap,
    required this.onCanvasDoubleTap,
    super.key,
  });

  final bool loading;
  final String? error;
  final KnowledgeBase? knowledgeBase;
  final List<KnowledgeNode> nodes;
  final KnowledgeNode? selectedNode;
  final int mapFocusRequestId;
  final _NodePositionSaveStatus positionSaveStatus;
  final bool layoutLocked;
  final bool showRelatedOnly;
  final ValueChanged<KnowledgeNode> onNodeTap;
  final ValueChanged<KnowledgeNode> onNodeDoubleTap;
  final void Function(KnowledgeNode node, Offset position) onNodePositionChanged;
  final void Function(KnowledgeNode node, Offset position) onNodePositionCommitted;
  final ValueChanged<KnowledgeNode> onCreateChildNode;
  final ValueChanged<KnowledgeNode> onRenameNode;
  final ValueChanged<KnowledgeNode> onDeleteNode;
  final VoidCallback onToggleLayoutLock;
  final VoidCallback onToggleRelatedOnly;
  final ValueChanged<KnowledgeNode> onToggleCollapseBranch;
  final VoidCallback onExpandAllBranches;
  final VoidCallback onOrganizeBranch;
  final VoidCallback onCanvasTap;
  final VoidCallback onCanvasDoubleTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MindVaultColors.background,
      child: Stack(
        children: [
          const Positioned.fill(child: _GridBackground()),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error != null)
            Center(child: Text(error!))
          else if (knowledgeBase == null)
            const Center(child: Text('Create or select a knowledge base'))
          else
            KnowledgeGraphCanvas(
              nodes: nodes,
              selectedNode: selectedNode,
              focusNodeRequestId: mapFocusRequestId,
              layoutLocked: layoutLocked,
              onNodeTap: onNodeTap,
              onNodeDoubleTap: onNodeDoubleTap,
              onNodePositionChanged: onNodePositionChanged,
              onNodePositionCommitted: onNodePositionCommitted,
              onCreateChildNode: onCreateChildNode,
              onRenameNode: onRenameNode,
              onDeleteNode: onDeleteNode,
              onToggleCollapseBranch: onToggleCollapseBranch,
              onCanvasTap: onCanvasTap,
              onCanvasDoubleTap: onCanvasDoubleTap,
            ),
          Positioned(
            top: 16,
            left: 20,
            child: _Breadcrumb(nodes: nodes, selectedNode: selectedNode, onSelect: onNodeTap),
          ),
          Positioned(
            top: 16,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _GraphToolsBar(
                  layoutLocked: layoutLocked,
                  showRelatedOnly: showRelatedOnly,
                  hasSelectedNode: selectedNode != null,
                  onToggleLayoutLock: onToggleLayoutLock,
                  onToggleRelatedOnly: onToggleRelatedOnly,
                  onExpandAllBranches: onExpandAllBranches,
                  onOrganizeBranch: onOrganizeBranch,
                ),
                const SizedBox(height: 10),
                _NodePositionSaveBadge(status: positionSaveStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NodePositionSaveBadge extends StatelessWidget {
  const _NodePositionSaveBadge({required this.status});

  final _NodePositionSaveStatus status;

  @override
  Widget build(BuildContext context) {
    final visible = status != _NodePositionSaveStatus.idle;
    final content = switch (status) {
      _NodePositionSaveStatus.saving => (Icons.sync, 'Saving position...', MindVaultColors.muted),
      _NodePositionSaveStatus.saved => (Icons.check_circle_outline, 'Position saved', MindVaultColors.success),
      _NodePositionSaveStatus.error => (Icons.error_outline, 'Save failed', MindVaultColors.error),
      _NodePositionSaveStatus.idle => (Icons.check, '', MindVaultColors.muted),
    };

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: MindVaultColors.surface.withValues(alpha: 0.94),
            border: Border.all(color: MindVaultColors.border),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(content.$1, size: 16, color: content.$3),
                const SizedBox(width: 8),
                Text(
                  content.$2,
                  style: TextStyle(color: content.$3, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GraphToolsBar extends StatelessWidget {
  const _GraphToolsBar({
    required this.layoutLocked,
    required this.showRelatedOnly,
    required this.hasSelectedNode,
    required this.onToggleLayoutLock,
    required this.onToggleRelatedOnly,
    required this.onExpandAllBranches,
    required this.onOrganizeBranch,
  });

  final bool layoutLocked;
  final bool showRelatedOnly;
  final bool hasSelectedNode;
  final VoidCallback onToggleLayoutLock;
  final VoidCallback onToggleRelatedOnly;
  final VoidCallback onExpandAllBranches;
  final VoidCallback onOrganizeBranch;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MindVaultColors.surface.withValues(alpha: 0.94),
        border: Border.all(color: MindVaultColors.border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: layoutLocked ? 'Unlock layout' : 'Lock layout',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onToggleLayoutLock,
                icon: Icon(layoutLocked ? Icons.lock_outline : Icons.lock_open_outlined, size: 18),
                color: layoutLocked ? MindVaultColors.primary : MindVaultColors.text,
              ),
            ),
            Tooltip(
              message: showRelatedOnly ? 'Show all nodes' : 'Show upstream and downstream',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: hasSelectedNode ? onToggleRelatedOnly : null,
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                color: showRelatedOnly ? MindVaultColors.primary : MindVaultColors.text,
              ),
            ),
            Tooltip(
              message: 'Expand all branches',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onExpandAllBranches,
                icon: const Icon(Icons.unfold_more_outlined, size: 18),
              ),
            ),
            Tooltip(
              message: 'Organize selected branch',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: hasSelectedNode ? onOrganizeBranch : null,
                icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridBackground extends StatelessWidget {
  const _GridBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MindVaultColors.text.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const step = 24.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.nodes, required this.selectedNode, required this.onSelect});

  final List<KnowledgeNode> nodes;
  final KnowledgeNode? selectedNode;
  final ValueChanged<KnowledgeNode> onSelect;

  @override
  Widget build(BuildContext context) {
    final chain = _chain();
    if (chain.isEmpty) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MindVaultColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MindVaultColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < chain.length; index++) ...[
              if (index > 0) const Icon(Icons.chevron_right, size: 16, color: MindVaultColors.muted),
              TextButton(
                onPressed: () => onSelect(chain[index]),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  foregroundColor: index == chain.length - 1 ? MindVaultColors.primary : MindVaultColors.muted,
                ),
                child: Text(chain[index].title),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<KnowledgeNode> _chain() {
    final selected = selectedNode;
    if (selected == null) {
      return const [];
    }
    final byId = {for (final node in nodes) node.id: node};
    final chain = <KnowledgeNode>[selected];
    var cursor = selected;
    while (cursor.parentId != null && byId[cursor.parentId] != null) {
      cursor = byId[cursor.parentId]!;
      chain.insert(0, cursor);
    }
    return chain;
  }
}

class _SearchDialog extends ConsumerStatefulWidget {
  const _SearchDialog();

  @override
  ConsumerState<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends ConsumerState<_SearchDialog> {
  final _controller = TextEditingController();
  List<SearchResult> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search nodes, documents...'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search nodes, documents...'),
              onSubmitted: (_) => _runSearch(),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _loading
                  ? const LinearProgressIndicator()
                  : SizedBox(
                      height: 280,
                      child: ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return ListTile(
                            title: Text(item.nodeTitle),
                            subtitle: Text(item.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: Text(item.matchedField, style: Theme.of(context).textTheme.labelMedium),
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton(onPressed: _runSearch, child: const Text('Search')),
      ],
    );
  }

  Future<void> _runSearch() async {
    setState(() => _loading = true);
    try {
      final results = await ref.read(searchRepositoryProvider).search(_controller.text.trim());
      if (mounted) {
        setState(() => _results = results);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
