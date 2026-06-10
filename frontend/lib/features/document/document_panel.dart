import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../app/theme.dart';
import '../../core/api/api_models.dart';

class DocumentPanel extends StatefulWidget {
  const DocumentPanel({
    required this.node,
    required this.document,
    required this.onSave,
    super.key,
  });

  final KnowledgeNode? node;
  final MindDocument? document;
  final Future<void> Function(MindDocument document) onSave;

  @override
  State<DocumentPanel> createState() => _DocumentPanelState();
}

class _DocumentPanelState extends State<DocumentPanel> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(DocumentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document?.nodeId != widget.document?.nodeId || oldWidget.node?.id != widget.node?.id) {
      _editing = false;
      _syncControllers();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: const BoxDecoration(
        color: MindVaultColors.surface,
        border: Border(left: BorderSide(color: MindVaultColors.border)),
      ),
      child: node == null ? _emptyState(context) : _documentBody(context, node),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('Select a node', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'Documents open here after you explore the map.',
              textAlign: TextAlign.center,
              style: TextStyle(color: MindVaultColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _documentBody(BuildContext context, KnowledgeNode node) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _editing
                        ? TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(border: InputBorder.none, hintText: 'Document title'),
                            style: Theme.of(context).textTheme.titleLarge,
                          )
                        : Text(
                            _titleController.text.isEmpty ? node.title : _titleController.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                  ),
                  _ToolbarButton(
                    label: 'Preview',
                    selected: !_editing,
                    icon: Icons.visibility_outlined,
                    onPressed: () => setState(() => _editing = false),
                  ),
                  _ToolbarButton(
                    label: 'Edit',
                    selected: _editing,
                    icon: Icons.edit_outlined,
                    onPressed: () => setState(() => _editing = true),
                  ),
                  _ToolbarButton(
                    label: 'Save',
                    selected: false,
                    icon: Icons.save_outlined,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(_updatedLabel(), style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _editing ? _editor() : _preview(),
          ),
        ),
      ],
    );
  }

  Widget _preview() {
    return Markdown(
      key: const ValueKey('preview'),
      data: _contentController.text.trim().isEmpty ? '_No document content yet._' : _contentController.text,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 40),
      styleSheet: MarkdownStyleSheet(
        h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: MindVaultColors.text),
        h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: MindVaultColors.text),
        h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: MindVaultColors.text),
        p: const TextStyle(fontSize: 14, height: 1.65, color: MindVaultColors.text),
        blockquote: const TextStyle(fontSize: 14, height: 1.6, color: MindVaultColors.muted),
        code: const TextStyle(fontSize: 13, backgroundColor: Color(0xFFF3F4F6)),
        tableHead: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tableBody: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _editor() {
    return Padding(
      key: const ValueKey('editor'),
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _contentController,
        expands: true,
        minLines: null,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          hintText: 'Write Markdown here',
          filled: true,
          fillColor: MindVaultColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: MindVaultColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: MindVaultColors.border),
          ),
        ),
        style: const TextStyle(fontSize: 14, height: 1.6),
      ),
    );
  }

  void _syncControllers() {
    final document = widget.document;
    final node = widget.node;
    _titleController.text = document?.title == 'Untitled' ? node?.title ?? '' : document?.title ?? node?.title ?? '';
    _contentController.text = document?.content ?? '# ${node?.title ?? 'Node'}\n\n';
  }

  String _updatedLabel() {
    final updatedAt = widget.document?.updatedAt;
    if (updatedAt == null || updatedAt.isEmpty) {
      return 'Not saved yet';
    }
    return 'Last updated $updatedAt';
  }

  Future<void> _save() async {
    final node = widget.node;
    if (node == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(
        MindDocument(
          id: widget.document?.id,
          nodeId: node.id,
          title: _titleController.text.trim().isEmpty ? node.title : _titleController.text.trim(),
          content: _contentController.text,
          updatedAt: widget.document?.updatedAt,
        ),
      );
      if (mounted) {
        setState(() => _editing = false);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        backgroundColor: selected ? MindVaultColors.selected : Colors.transparent,
        foregroundColor: selected ? MindVaultColors.primary : MindVaultColors.text,
      ),
    );
  }
}
