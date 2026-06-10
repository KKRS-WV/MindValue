import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_models.dart';
import '../../core/api/providers.dart';
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
  _WorkspaceView _workspaceView = _WorkspaceView.map;
  bool _loadingKnowledgeBases = true;
  bool _loadingGraph = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadKnowledgeBases);
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authTokenProvider);
    if (token == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign in'),
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
            onAdd: _selectedKnowledgeBase == null ? _createKnowledgeBase : _createChildNode,
            onEditNode: _selectedNode == null ? null : _renameSelectedNode,
            onDeleteNode: _canDeleteSelectedNode ? _deleteSelectedNode : null,
            onWorkspaceViewChanged: (view) => setState(() => _workspaceView = view),
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
                    selectedNode: _selectedNode,
                    onNodeTap: _selectNode,
                    onNodeDoubleTap: _focusNode,
                    onNodePositionChanged: _moveNode,
                    onNodePositionCommitted: _saveNodePosition,
                    onCanvasTap: _clearSelection,
                    onCanvasDoubleTap: _clearFocus,
                    onSwitchToMap: () => setState(() => _workspaceView = _WorkspaceView.map),
                  ),
                ),
                SizedBox(
                  width: 400,
                  child: DocumentPanel(
                    node: _selectedNode,
                    document: _document,
                    onSave: _saveDocument,
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
    setState(() {
      _selectedKnowledgeBase = knowledgeBase;
      _selectedNode = null;
      _document = null;
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

  Future<void> _selectNode(KnowledgeNode node) async {
    setState(() {
      _selectedNode = node;
      _document = null;
    });
    await _loadDocument(node.id);
  }

  Future<void> _focusNode(KnowledgeNode node) async {
    await _selectNode(node);
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save node position')));
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedNode = null;
      _document = null;
    });
  }

  void _clearFocus() {
    _clearSelection();
  }

  Future<void> _loadDocument(int nodeId) async {
    final document = await ref.read(documentRepositoryProvider).getByNode(nodeId);
    if (mounted) {
      setState(() => _document = document);
    }
  }

  Future<void> _saveDocument(MindDocument document) async {
    final saved = await ref.read(documentRepositoryProvider).save(document);
    if (mounted) {
      setState(() => _document = saved);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document saved')));
    }
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

  Future<void> _createChildNode() async {
    final parent = _selectedNode;
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

    await ref.read(nodeRepositoryProvider).create(
          knowledgeBaseId: knowledgeBase.id,
          parentId: parent.id,
          title: title.trim(),
          description: '${title.trim()} notes',
        );
    await _loadGraph(knowledgeBase);
  }

  Future<void> _renameSelectedNode() async {
    final node = _selectedNode;
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

  Future<void> _deleteSelectedNode() async {
    final node = _selectedNode;
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
        await _selectNode(node);
        return;
      }
    }
  }
}

enum _WorkspaceView { map, list }

class _TopNavigation extends StatelessWidget {
  const _TopNavigation({
    required this.workspaceView,
    required this.onSearch,
    required this.onAdd,
    required this.onEditNode,
    required this.onDeleteNode,
    required this.onWorkspaceViewChanged,
    required this.onUser,
  });

  final _WorkspaceView workspaceView;
  final VoidCallback onSearch;
  final VoidCallback onAdd;
  final VoidCallback? onEditNode;
  final VoidCallback? onDeleteNode;
  final ValueChanged<_WorkspaceView> onWorkspaceViewChanged;
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
    required this.selectedNode,
    required this.onNodeTap,
    required this.onNodeDoubleTap,
    required this.onNodePositionChanged,
    required this.onNodePositionCommitted,
    required this.onCanvasTap,
    required this.onCanvasDoubleTap,
    required this.onSwitchToMap,
  });

  final _WorkspaceView view;
  final bool loading;
  final String? error;
  final KnowledgeBase? knowledgeBase;
  final List<KnowledgeNode> nodes;
  final KnowledgeNode? selectedNode;
  final ValueChanged<KnowledgeNode> onNodeTap;
  final ValueChanged<KnowledgeNode> onNodeDoubleTap;
  final void Function(KnowledgeNode node, Offset position) onNodePositionChanged;
  final void Function(KnowledgeNode node, Offset position) onNodePositionCommitted;
  final VoidCallback onCanvasTap;
  final VoidCallback onCanvasDoubleTap;
  final VoidCallback onSwitchToMap;

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
              nodes: nodes,
              selectedNode: selectedNode,
              onNodeTap: onNodeTap,
              onNodeDoubleTap: onNodeDoubleTap,
              onNodePositionChanged: onNodePositionChanged,
              onNodePositionCommitted: onNodePositionCommitted,
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
              onLocateInMap: (node) {
                onNodeTap(node);
                onSwitchToMap();
              },
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
  final Set<int> _expandedNodeIds = {};
  bool _knowledgeBaseExpanded = true;

  @override
  void didUpdateWidget(covariant _TraditionalWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.knowledgeBase?.id != widget.knowledgeBase?.id) {
      _expandedNodeIds.clear();
      _knowledgeBaseExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tree = _buildTree();
    final flattenedNodes = _flattenNodes(tree.childrenByParent);
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
                            const Text('Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                                          const Padding(
                                            padding: EdgeInsets.all(28),
                                            child: Text('No nodes yet.', style: TextStyle(color: MindVaultColors.muted)),
                                          )
                                        else
                                          ...flattenedNodes.map((item) {
                                            final selected = widget.selectedNode?.id == item.node.id;
                                            final isLast = item == flattenedNodes.last;
                                            return _TraditionalNodeRow(
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

  List<_TraditionalNodeItem> _flattenNodes(Map<int?, List<KnowledgeNode>> childrenByParent) {
    final result = <_TraditionalNodeItem>[];
    void walk(KnowledgeNode node, int depth, Set<int> path) {
      if (path.contains(node.id)) {
        return;
      }
      final children = childrenByParent[node.id] ?? const <KnowledgeNode>[];
      final hasChildren = children.isNotEmpty;
      result.add(_TraditionalNodeItem(node: node, depth: depth, hasChildren: hasChildren));
      if (hasChildren && !_expandedNodeIds.contains(node.id)) {
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

  void _toggleNode(int id) {
    setState(() {
      if (_expandedNodeIds.contains(id)) {
        _expandedNodeIds.remove(id);
      } else {
        _expandedNodeIds.add(id);
      }
    });
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
    required this.onNodeTap,
    required this.onNodeDoubleTap,
    required this.onNodePositionChanged,
    required this.onNodePositionCommitted,
    required this.onCanvasTap,
    required this.onCanvasDoubleTap,
    super.key,
  });

  final bool loading;
  final String? error;
  final KnowledgeBase? knowledgeBase;
  final List<KnowledgeNode> nodes;
  final KnowledgeNode? selectedNode;
  final ValueChanged<KnowledgeNode> onNodeTap;
  final ValueChanged<KnowledgeNode> onNodeDoubleTap;
  final void Function(KnowledgeNode node, Offset position) onNodePositionChanged;
  final void Function(KnowledgeNode node, Offset position) onNodePositionCommitted;
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
              onNodeTap: onNodeTap,
              onNodeDoubleTap: onNodeDoubleTap,
              onNodePositionChanged: onNodePositionChanged,
              onNodePositionCommitted: onNodePositionCommitted,
              onCanvasTap: onCanvasTap,
              onCanvasDoubleTap: onCanvasDoubleTap,
            ),
          Positioned(
            top: 16,
            left: 20,
            child: _Breadcrumb(nodes: nodes, selectedNode: selectedNode, onSelect: onNodeTap),
          ),
        ],
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
