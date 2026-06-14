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
  DocumentPanelState createState() => DocumentPanelState();
}

class DocumentPanelState extends State<DocumentPanel> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _lastSavedTitle = '';
  String _lastSavedContent = '';
  bool _editing = false;
  bool _saving = false;
  bool _syncingControllers = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_handleTextChanged);
    _contentController.addListener(_handleTextChanged);
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
    _titleController.removeListener(_handleTextChanged);
    _contentController.removeListener(_handleTextChanged);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  bool get hasUnsavedChanges =>
      _titleController.text != _lastSavedTitle || _contentController.text != _lastSavedContent;

  Future<bool> confirmDiscardIfNeeded() async {
    if (!hasUnsavedChanges) {
      return true;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unsaved changes'),
          content: const Text('The current document has unsaved edits. Discard them and switch away?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep editing')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
          ],
        );
      },
    );
    return result ?? false;
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
                  if (hasUnsavedChanges)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: _DirtyDot(),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                hasUnsavedChanges ? 'Unsaved changes' : _updatedLabel(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: hasUnsavedChanges ? MindVaultColors.warning : MindVaultColors.muted,
                    ),
              ),
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
    final isEmpty = _contentController.text.trim().isEmpty;
    if (isEmpty) {
      return Center(
        key: const ValueKey('empty-preview'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notes_outlined, size: 36, color: MindVaultColors.muted),
              const SizedBox(height: 12),
              Text('No document yet', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              const Text(
                'Switch to Edit to capture the notes behind this node.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MindVaultColors.muted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Start writing'),
              ),
            ],
          ),
        ),
      );
    }
    return Markdown(
      key: const ValueKey('preview'),
      data: _contentController.text,
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
      child: Column(
        children: [
          _MarkdownToolbar(onInsert: _insertMarkdown),
          const SizedBox(height: 10),
          Expanded(
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
          ),
        ],
      ),
    );
  }

  void _syncControllers() {
    final document = widget.document;
    final node = widget.node;
    final title = document?.title == 'Untitled' ? node?.title ?? '' : document?.title ?? node?.title ?? '';
    final content = document?.content ?? '';
    _syncingControllers = true;
    _titleController.text = title;
    _contentController.text = content;
    _syncingControllers = false;
    _lastSavedTitle = title;
    _lastSavedContent = content;
  }

  void _handleTextChanged() {
    if (_syncingControllers || !mounted) {
      return;
    }
    setState(() {});
  }

  void _insertMarkdown(String prefix, {String suffix = '', String placeholder = 'text'}) {
    final selection = _contentController.selection;
    final text = _contentController.text;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final selected = hasSelection ? text.substring(start, end) : placeholder;
    final inserted = '$prefix$selected$suffix';
    final nextText = text.replaceRange(start, end, inserted);
    final cursor = start + inserted.length;
    _contentController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: cursor),
    );
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
        setState(() {
          _lastSavedTitle = _titleController.text.trim().isEmpty ? node.title : _titleController.text.trim();
          _lastSavedContent = _contentController.text;
          _editing = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({required this.onInsert});

  final void Function(String prefix, {String suffix, String placeholder}) onInsert;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MindVaultColors.surface,
        border: Border.all(color: MindVaultColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          children: [
            _MarkdownToolButton(label: 'H1', onPressed: () => onInsert('# ', placeholder: 'Heading')),
            _MarkdownToolButton(label: 'H2', onPressed: () => onInsert('## ', placeholder: 'Heading')),
            _MarkdownToolButton(icon: Icons.format_list_bulleted, label: 'Bullet', onPressed: () => onInsert('- ')),
            _MarkdownToolButton(icon: Icons.check_box_outlined, label: 'Checklist', onPressed: () => onInsert('- [ ] ')),
            _MarkdownToolButton(icon: Icons.format_quote, label: 'Quote', onPressed: () => onInsert('> ')),
            _MarkdownToolButton(icon: Icons.code, label: 'Code', onPressed: () => onInsert('`', suffix: '`', placeholder: 'code')),
            _MarkdownToolButton(
              icon: Icons.table_chart_outlined,
              label: 'Table',
              onPressed: () => onInsert(
                '\n| Column | Value |\n| --- | --- |\n| ',
                suffix: ' | |\n',
                placeholder: 'Item',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkdownToolButton extends StatelessWidget {
  const _MarkdownToolButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: icon == null ? Text(label, style: const TextStyle(fontWeight: FontWeight.w700)) : Icon(icon, size: 18),
      style: IconButton.styleFrom(
        foregroundColor: MindVaultColors.text,
        hoverColor: MindVaultColors.background,
      ),
    );
  }
}

class _DirtyDot extends StatelessWidget {
  const _DirtyDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MindVaultColors.warning,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const SizedBox(width: 8, height: 8),
    );
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
