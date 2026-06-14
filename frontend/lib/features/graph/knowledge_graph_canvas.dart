import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/api/api_models.dart';

class KnowledgeGraphCanvas extends StatefulWidget {
  const KnowledgeGraphCanvas({
    required this.nodes,
    required this.selectedNode,
    required this.focusNodeRequestId,
    required this.layoutLocked,
    required this.onNodeTap,
    required this.onNodeDoubleTap,
    required this.onNodePositionChanged,
    required this.onNodePositionCommitted,
    required this.onCreateChildNode,
    required this.onRenameNode,
    required this.onDeleteNode,
    required this.onToggleCollapseBranch,
    required this.onCanvasTap,
    required this.onCanvasDoubleTap,
    super.key,
  });

  final List<KnowledgeNode> nodes;
  final KnowledgeNode? selectedNode;
  final int focusNodeRequestId;
  final bool layoutLocked;
  final ValueChanged<KnowledgeNode> onNodeTap;
  final ValueChanged<KnowledgeNode> onNodeDoubleTap;
  final void Function(KnowledgeNode node, Offset position) onNodePositionChanged;
  final void Function(KnowledgeNode node, Offset position) onNodePositionCommitted;
  final ValueChanged<KnowledgeNode> onCreateChildNode;
  final ValueChanged<KnowledgeNode> onRenameNode;
  final ValueChanged<KnowledgeNode> onDeleteNode;
  final ValueChanged<KnowledgeNode> onToggleCollapseBranch;
  final VoidCallback onCanvasTap;
  final VoidCallback onCanvasDoubleTap;

  @override
  State<KnowledgeGraphCanvas> createState() => _KnowledgeGraphCanvasState();
}

class _KnowledgeGraphCanvasState extends State<KnowledgeGraphCanvas> with SingleTickerProviderStateMixin {
  static const _maxCanvasScale = 3.5;
  static const _minCanvasScaleFloor = 0.2;
  static const _wheelScaleFactor = 240.0;

  final _transformationController = TransformationController();
  late final AnimationController _transformAnimationController;
  Animation<Matrix4>? _transformAnimation;
  int? _focusedNodeId;
  int? _hoveredNodeId;
  int? _draggingNodeId;
  Offset? _lastDragPosition;
  double _dragDistance = 0;
  String? _canvasViewKey;
  int _handledFocusNodeRequestId = 0;

  @override
  void initState() {
    super.initState();
    BrowserContextMenu.disableContextMenu();
    _transformationController.addListener(_handleTransformChanged);
    _transformAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        final animation = _transformAnimation;
        if (animation != null) {
          _transformationController.value = animation.value;
        }
      });
  }

  @override
  void dispose() {
    BrowserContextMenu.enableContextMenu();
    _transformationController.removeListener(_handleTransformChanged);
    _transformAnimationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        final layout = _GraphLayout(widget.nodes, viewportSize);
        final canvasSize = layout.canvasSize;
        final minScale = _minCanvasScale(canvasSize, viewportSize);
        final canvasViewKey = 'top-left-v2:${_rootNodeId(widget.nodes)}:${viewportSize.width.round()}x${viewportSize.height.round()}';
        if (_canvasViewKey != canvasViewKey) {
          _canvasViewKey = canvasViewKey;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _canvasViewKey == canvasViewKey) {
              _fitCanvasToViewport(canvasSize, viewportSize);
            }
          });
        }
        if (widget.focusNodeRequestId != _handledFocusNodeRequestId && widget.selectedNode != null) {
          _handledFocusNodeRequestId = widget.focusNodeRequestId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || widget.selectedNode == null) {
              return;
            }
            _centerNodeInViewport(widget.selectedNode!, layout.positions, canvasSize, viewportSize);
          });
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _focusedNodeId = null);
                  widget.onCanvasTap();
                },
                onDoubleTap: () {
                  setState(() => _focusedNodeId = null);
                  widget.onCanvasDoubleTap();
                },
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  constrained: false,
                  alignment: Alignment.topLeft,
                  boundaryMargin: EdgeInsets.zero,
                  minScale: minScale,
                  maxScale: _maxCanvasScale,
                  scaleFactor: _wheelScaleFactor,
                  scaleEnabled: _draggingNodeId == null,
                  trackpadScrollCausesScale: false,
                  panEnabled: _draggingNodeId == null,
                  onInteractionStart: (_) => _transformAnimationController.stop(),
                  onInteractionEnd: (_) => _clampCurrentTransform(canvasSize, viewportSize),
                  child: SizedBox(
                    width: canvasSize.width,
                    height: canvasSize.height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _EdgePainter(
                              nodes: widget.nodes,
                              positions: layout.positions,
                              focusedNodeId: _focusedNodeId,
                              hoveredNodeId: _hoveredNodeId,
                            ),
                          ),
                        ),
                        for (final node in widget.nodes)
                          Positioned(
                            key: ValueKey(node.id),
                            left: layout.positions[node.id]!.dx - layout.sizeFor(node).width / 2,
                            top: layout.positions[node.id]!.dy - layout.sizeFor(node).height / 2,
                            child: _KnowledgeGraphNode(
                              node: node,
                              root: node.parentId == null,
                              selected: widget.selectedNode?.id == node.id,
                              dimmed: _focusedNodeId != null && !_isRelated(node.id, widget.nodes, _focusedNodeId!),
                              layoutLocked: widget.layoutLocked,
                              onTap: () => widget.onNodeTap(node),
                              onDoubleTap: () {
                                setState(() => _focusedNodeId = node.id);
                                widget.onNodeDoubleTap(node);
                              },
                              onSecondaryTapDown: (details) => _showNodeContextMenu(
                                context,
                                node,
                                details.globalPosition,
                                layout.positions,
                                canvasSize,
                                viewportSize,
                              ),
                              onDragStart: () {
                                if (widget.layoutLocked) {
                                  return;
                                }
                                setState(() {
                                  _draggingNodeId = node.id;
                                  _lastDragPosition = layout.positions[node.id];
                                  _dragDistance = 0;
                                });
                                widget.onNodeTap(node);
                              },
                              onDragUpdate: (delta) {
                                if (widget.layoutLocked) {
                                  return;
                                }
                                final current = _lastDragPosition ?? layout.positions[node.id];
                                if (current == null) {
                                  return;
                                }
                                final scale = _effectiveScale;
                                final rawMoved = current + delta / scale;
                                final moved = layout.clampPosition(rawMoved, node);
                                _dragDistance += delta.distance;
                                _lastDragPosition = moved;
                                widget.onNodePositionChanged(node, moved);
                              },
                              onDragEnd: () {
                                if (widget.layoutLocked) {
                                  return;
                                }
                                final position = _lastDragPosition;
                                final shouldCommit = _dragDistance > 2;
                                setState(() {
                                  _draggingNodeId = null;
                                  _lastDragPosition = null;
                                  _dragDistance = 0;
                                });
                                if (position != null && shouldCommit) {
                                  widget.onNodePositionCommitted(node, position);
                                }
                              },
                              onHover: (hovering) => setState(() => _hoveredNodeId = hovering ? node.id : null),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: _GraphNavigationOverlay(
                nodes: widget.nodes,
                positions: layout.positions,
                selectedNode: widget.selectedNode,
                canvasSize: canvasSize,
                viewportSize: viewportSize,
                transform: _transformationController.value,
                scale: _effectiveScale,
                onFit: () => _fitGraphToViewport(layout.graphBounds, canvasSize, viewportSize),
                onCenterSelected: widget.selectedNode == null ? null : () => _centerNodeInViewport(widget.selectedNode!, layout.positions, canvasSize, viewportSize),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleTransformChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showNodeContextMenu(
    BuildContext context,
    KnowledgeNode node,
    Offset globalPosition,
    Map<int, Offset> positions,
    Size canvasSize,
    Size viewportSize,
  ) async {
    widget.onNodeTap(node);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final localPosition = overlay.globalToLocal(globalPosition);
    final selected = await showMenu<_NodeContextAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(localPosition.dx, localPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: _NodeContextAction.createChild,
          child: _NodeContextMenuItem(icon: Icons.add_circle_outline, label: 'New child node'),
        ),
        const PopupMenuItem(
          value: _NodeContextAction.rename,
          child: _NodeContextMenuItem(icon: Icons.edit_outlined, label: 'Rename'),
        ),
        const PopupMenuItem(
          value: _NodeContextAction.locate,
          child: _NodeContextMenuItem(icon: Icons.center_focus_strong_outlined, label: 'Locate'),
        ),
        const PopupMenuItem(
          value: _NodeContextAction.toggleCollapse,
          child: _NodeContextMenuItem(icon: Icons.account_tree_outlined, label: 'Collapse / expand branch'),
        ),
        const PopupMenuItem(
          value: _NodeContextAction.copyTitle,
          child: _NodeContextMenuItem(icon: Icons.copy_outlined, label: 'Copy title'),
        ),
        PopupMenuItem(
          value: _NodeContextAction.delete,
          enabled: node.parentId != null,
          child: _NodeContextMenuItem(
            icon: Icons.delete_outline,
            label: 'Delete',
            destructive: node.parentId != null,
          ),
        ),
      ],
    );

    if (!mounted || selected == null) {
      return;
    }
    switch (selected) {
      case _NodeContextAction.createChild:
        widget.onCreateChildNode(node);
        break;
      case _NodeContextAction.rename:
        widget.onRenameNode(node);
        break;
      case _NodeContextAction.delete:
        if (node.parentId != null) {
          widget.onDeleteNode(node);
        }
        break;
      case _NodeContextAction.locate:
        _centerNodeInViewport(node, positions, canvasSize, viewportSize);
        break;
      case _NodeContextAction.toggleCollapse:
        widget.onToggleCollapseBranch(node);
        break;
      case _NodeContextAction.copyTitle:
        await Clipboard.setData(ClipboardData(text: node.title));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Node title copied')));
        }
        break;
    }
  }

  void _fitGraphToViewport(Rect graphBounds, Size canvasSize, Size viewportSize) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0 || graphBounds.width <= 0 || graphBounds.height <= 0) {
      return;
    }
    final paddedBounds = graphBounds.inflate(96);
    final scale = math.min(
      viewportSize.width / paddedBounds.width,
      viewportSize.height / paddedBounds.height,
    ).clamp(_minCanvasScaleFloor, 1.0).toDouble();
    final viewportCenter = Offset(viewportSize.width / 2, viewportSize.height / 2);
    final translation = viewportCenter - paddedBounds.center * scale;
    _animateCanvasTransform(canvasSize, viewportSize, scale, translation);
  }

  void _centerNodeInViewport(KnowledgeNode node, Map<int, Offset> positions, Size canvasSize, Size viewportSize) {
    final position = positions[node.id];
    if (position == null || viewportSize.width <= 0 || viewportSize.height <= 0) {
      return;
    }
    final scale = _boundedScale(canvasSize, viewportSize, _effectiveScale);
    final viewportCenter = Offset(viewportSize.width / 2, viewportSize.height / 2);
    _animateCanvasTransform(canvasSize, viewportSize, scale, viewportCenter - position * scale);
  }

  void _fitCanvasToViewport(Size canvasSize, Size viewportSize) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0 || viewportSize.width <= 0 || viewportSize.height <= 0) {
      return;
    }
    final scale = _minCanvasScale(canvasSize, viewportSize);
    final dx = (viewportSize.width - canvasSize.width * scale) / 2;
    final dy = (viewportSize.height - canvasSize.height * scale) / 2;
    _setCanvasTransform(canvasSize, viewportSize, scale, Offset(dx, dy));
  }

  double _minCanvasScale(Size canvasSize, Size viewportSize) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0 || viewportSize.width <= 0 || viewportSize.height <= 0) {
      return _minCanvasScaleFloor;
    }
    return math.min(
      viewportSize.width / canvasSize.width,
      viewportSize.height / canvasSize.height,
    ).clamp(_minCanvasScaleFloor, 1.0).toDouble();
  }

  void _setCanvasTransform(Size canvasSize, Size viewportSize, double scale, Offset translation) {
    _transformAnimationController.stop();
    _transformationController.value = _matrixFor(canvasSize, viewportSize, scale, translation);
  }

  void _clampCurrentTransform(Size canvasSize, Size viewportSize) {
    final current = _transformationController.value;
    final scale = _boundedScale(canvasSize, viewportSize, current.getMaxScaleOnAxis());
    final translation = current.getTranslation();
    final offset = Offset(translation.x, translation.y);
    final clampedOffset = _clampedTranslation(canvasSize, viewportSize, scale, offset);
    if ((scale - current.getMaxScaleOnAxis()).abs() < 0.0001 && (clampedOffset - offset).distance < 0.5) {
      return;
    }
    _animateCanvasTransform(canvasSize, viewportSize, scale, clampedOffset);
  }

  double _boundedScale(Size canvasSize, Size viewportSize, double scale) {
    return scale.clamp(_minCanvasScale(canvasSize, viewportSize), _maxCanvasScale).toDouble();
  }

  Offset _clampedTranslation(Size canvasSize, Size viewportSize, double scale, Offset translation) {
    final scaledWidth = canvasSize.width * scale;
    final scaledHeight = canvasSize.height * scale;
    final tx = scaledWidth <= viewportSize.width ? (viewportSize.width - scaledWidth) / 2 : translation.dx.clamp(viewportSize.width - scaledWidth, 0).toDouble();
    final ty = scaledHeight <= viewportSize.height ? (viewportSize.height - scaledHeight) / 2 : translation.dy.clamp(viewportSize.height - scaledHeight, 0).toDouble();
    return Offset(tx, ty);
  }

  void _animateCanvasTransform(Size canvasSize, Size viewportSize, double scale, Offset translation) {
    _transformAnimationController.stop();
    _transformAnimation = Matrix4Tween(
      begin: _transformationController.value.clone(),
      end: _matrixFor(canvasSize, viewportSize, scale, translation),
    ).animate(CurvedAnimation(parent: _transformAnimationController, curve: Curves.easeOutCubic));
    _transformAnimationController.forward(from: 0);
  }

  Matrix4 _matrixFor(Size canvasSize, Size viewportSize, double scale, Offset translation) {
    final boundedScale = _boundedScale(canvasSize, viewportSize, scale);
    final clampedTranslation = _clampedTranslation(canvasSize, viewportSize, boundedScale, translation);
    final matrix = Matrix4.identity();
    matrix.storage[0] = boundedScale;
    matrix.storage[5] = boundedScale;
    matrix.storage[12] = clampedTranslation.dx;
    matrix.storage[13] = clampedTranslation.dy;
    return matrix;
  }

  int _rootNodeId(List<KnowledgeNode> nodes) {
    for (final node in nodes) {
      if (node.parentId == null) {
        return node.id;
      }
    }
    return nodes.isEmpty ? 0 : nodes.first.id;
  }

  double get _effectiveScale {
    return _transformationController.value.getMaxScaleOnAxis();
  }

  bool _isRelated(int nodeId, List<KnowledgeNode> nodes, int focusedNodeId) {
    if (nodeId == focusedNodeId) {
      return true;
    }
    final byId = {for (final node in nodes) node.id: node};
    final node = byId[nodeId];
    if (node?.parentId == focusedNodeId) {
      return true;
    }
    var cursor = byId[focusedNodeId];
    while (cursor?.parentId != null) {
      if (cursor!.parentId == nodeId) {
        return true;
      }
      cursor = byId[cursor.parentId];
    }
    return false;
  }
}

class _GraphNavigationOverlay extends StatelessWidget {
  const _GraphNavigationOverlay({
    required this.nodes,
    required this.positions,
    required this.selectedNode,
    required this.canvasSize,
    required this.viewportSize,
    required this.transform,
    required this.scale,
    required this.onFit,
    required this.onCenterSelected,
  });

  final List<KnowledgeNode> nodes;
  final Map<int, Offset> positions;
  final KnowledgeNode? selectedNode;
  final Size canvasSize;
  final Size viewportSize;
  final Matrix4 transform;
  final double scale;
  final VoidCallback onFit;
  final VoidCallback? onCenterSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: MindVaultColors.surface.withValues(alpha: 0.94),
            border: Border.all(color: MindVaultColors.border),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Fit to screen',
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.fit_screen_outlined, size: 18),
                    onPressed: onFit,
                  ),
                ),
                Tooltip(
                  message: 'Center selected node',
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.center_focus_strong_outlined, size: 18),
                    onPressed: onCenterSelected,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 54,
                  child: Text(
                    '${(scale * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MindVaultColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _MiniMap(
          nodes: nodes,
          positions: positions,
          selectedNode: selectedNode,
          canvasSize: canvasSize,
          viewportSize: viewportSize,
          transform: transform,
        ),
      ],
    );
  }
}

enum _NodeContextAction { createChild, rename, delete, locate, toggleCollapse, copyTitle }

class _NodeContextMenuItem extends StatelessWidget {
  const _NodeContextMenuItem({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? MindVaultColors.error : MindVaultColors.text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({
    required this.nodes,
    required this.positions,
    required this.selectedNode,
    required this.canvasSize,
    required this.viewportSize,
    required this.transform,
  });

  final List<KnowledgeNode> nodes;
  final Map<int, Offset> positions;
  final KnowledgeNode? selectedNode;
  final Size canvasSize;
  final Size viewportSize;
  final Matrix4 transform;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MindVaultColors.surface.withValues(alpha: 0.94),
        border: Border.all(color: MindVaultColors.border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        width: 184,
        height: 124,
        child: CustomPaint(
          painter: _MiniMapPainter(
            nodes: nodes,
            positions: positions,
            selectedNode: selectedNode,
            canvasSize: canvasSize,
            viewportSize: viewportSize,
            transform: transform,
          ),
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter({
    required this.nodes,
    required this.positions,
    required this.selectedNode,
    required this.canvasSize,
    required this.viewportSize,
    required this.transform,
  });

  final List<KnowledgeNode> nodes;
  final Map<int, Offset> positions;
  final KnowledgeNode? selectedNode;
  final Size canvasSize;
  final Size viewportSize;
  final Matrix4 transform;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 10.0;
    final available = Rect.fromLTWH(padding, padding, size.width - padding * 2, size.height - padding * 2);
    if (canvasSize.width <= 0 || canvasSize.height <= 0 || available.width <= 0 || available.height <= 0) {
      return;
    }

    final canvasScale = math.min(available.width / canvasSize.width, available.height / canvasSize.height);
    final mapSize = Size(canvasSize.width * canvasScale, canvasSize.height * canvasScale);
    final mapRect = Rect.fromLTWH(
      available.left + (available.width - mapSize.width) / 2,
      available.top + (available.height - mapSize.height) / 2,
      mapSize.width,
      mapSize.height,
    );

    final backgroundPaint = Paint()..color = MindVaultColors.background;
    final borderPaint = Paint()
      ..color = MindVaultColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final edgePaint = Paint()
      ..color = MindVaultColors.border.withValues(alpha: 0.75)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final nodePaint = Paint()..color = MindVaultColors.muted.withValues(alpha: 0.55);
    final selectedPaint = Paint()..color = MindVaultColors.primary;
    final rootPaint = Paint()..color = const Color(0xFF1F2937);
    final viewportPaint = Paint()
      ..color = MindVaultColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final viewportBorderPaint = Paint()
      ..color = MindVaultColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawRRect(RRect.fromRectAndRadius(mapRect, const Radius.circular(6)), backgroundPaint);

    Offset mapPoint(Offset point) {
      return mapRect.topLeft + Offset(point.dx * canvasScale, point.dy * canvasScale);
    }

    for (final node in nodes) {
      if (node.parentId == null || positions[node.parentId] == null || positions[node.id] == null) {
        continue;
      }
      final from = mapPoint(positions[node.parentId]!);
      final to = mapPoint(positions[node.id]!);
      canvas.drawLine(from, to, edgePaint);
    }

    for (final node in nodes) {
      final position = positions[node.id];
      if (position == null) {
        continue;
      }
      final point = mapPoint(position);
      final paint = selectedNode?.id == node.id ? selectedPaint : node.parentId == null ? rootPaint : nodePaint;
      final radius = node.parentId == null ? 3.8 : 3.0;
      canvas.drawCircle(point, radius, paint);
    }

    final viewport = _visibleCanvasRect();
    if (viewport.width > 0 && viewport.height > 0) {
      final rect = Rect.fromLTRB(
        mapRect.left + viewport.left * canvasScale,
        mapRect.top + viewport.top * canvasScale,
        mapRect.left + viewport.right * canvasScale,
        mapRect.top + viewport.bottom * canvasScale,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), viewportPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), viewportBorderPaint);
    }

    canvas.drawRRect(RRect.fromRectAndRadius(mapRect, const Radius.circular(6)), borderPaint);
  }

  Rect _visibleCanvasRect() {
    final scale = transform.getMaxScaleOnAxis();
    if (scale <= 0) {
      return Rect.zero;
    }
    final translation = transform.getTranslation();
    final left = math.max(0.0, -translation.x / scale);
    final top = math.max(0.0, -translation.y / scale);
    final right = math.min(canvasSize.width, (viewportSize.width - translation.x) / scale);
    final bottom = math.min(canvasSize.height, (viewportSize.height - translation.y) / scale);
    if (right <= left || bottom <= top) {
      return Rect.zero;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) => true;
}

class _GraphLayout {
  _GraphLayout(this.nodes, this.viewportSize) {
    _compute();
  }

  final List<KnowledgeNode> nodes;
  final Size viewportSize;
  final Map<int, Offset> positions = {};
  Rect graphBounds = Rect.zero;
  Size canvasSize = const Size(820, 640);
  static const _edgePadding = 72.0;
  static const _ringSpacing = 170.0;
  static const _workspaceScale = 3.0;

  Size sizeFor(KnowledgeNode node) {
    return node.parentId == null ? const Size(140, 52) : const Size(128, 48);
  }

  Offset clampPosition(Offset position, KnowledgeNode node) {
    final size = sizeFor(node);
    final minX = size.width / 2 + 16;
    final minY = size.height / 2 + 16;
    final maxX = math.max(minX, canvasSize.width - size.width / 2 - 16);
    final maxY = math.max(minY, canvasSize.height - size.height / 2 - 16);
    return Offset(
      position.dx.clamp(minX, maxX).toDouble(),
      position.dy.clamp(minY, maxY).toDouble(),
    );
  }

  void _compute() {
    if (nodes.isEmpty) {
      return;
    }
    canvasSize = Size(
      math.max(viewportSize.width * _workspaceScale, viewportSize.width),
      math.max(viewportSize.height * _workspaceScale, viewportSize.height),
    );

    final childrenByParent = <int?, List<KnowledgeNode>>{};
    for (final node in nodes) {
      childrenByParent.putIfAbsent(node.parentId, () => []).add(node);
    }
    for (final siblings in childrenByParent.values) {
      siblings.sort((a, b) => a.title.compareTo(b.title));
    }

    final root = childrenByParent[null]?.first ?? nodes.first;
    final rawPositions = <int, Offset>{};
    final leafWeights = <int, int>{};

    int measure(KnowledgeNode node, Set<int> path) {
      if (path.contains(node.id)) {
        return 1;
      }
      final children = childrenByParent[node.id] ?? const <KnowledgeNode>[];
      if (children.isEmpty) {
        leafWeights[node.id] = 1;
        return 1;
      }
      final nextPath = {...path, node.id};
      final weight = children.fold<int>(0, (total, child) => total + measure(child, nextPath));
      leafWeights[node.id] = math.max(1, weight);
      return leafWeights[node.id]!;
    }

    void place(KnowledgeNode node, int depth, double startAngle, double endAngle, Set<int> path) {
      final angle = (startAngle + endAngle) / 2;
      if (depth == 0) {
        rawPositions[node.id] = Offset.zero;
      } else {
        final radius = _ringSpacing * depth;
        rawPositions[node.id] = Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      }

      if (path.contains(node.id)) {
        return;
      }
      final children = childrenByParent[node.id] ?? const <KnowledgeNode>[];
      if (children.isEmpty) {
        return;
      }

      if (children.length == 1) {
        place(children.first, depth + 1, startAngle, endAngle, {...path, node.id});
        return;
      }

      final totalWeight = children.fold<int>(0, (total, child) => total + (leafWeights[child.id] ?? 1));
      var cursor = startAngle;
      for (final child in children) {
        final share = (endAngle - startAngle) * ((leafWeights[child.id] ?? 1) / totalWeight);
        place(child, depth + 1, cursor, cursor + share, {...path, node.id});
        cursor += share;
      }
    }

    measure(root, const <int>{});
    place(root, 0, -math.pi / 2, math.pi * 3 / 2, const <int>{});

    final missingNodes = nodes.where((node) => rawPositions[node.id] == null).toList();
    for (var index = 0; index < missingNodes.length; index++) {
      final angle = -math.pi / 2 + math.pi * 2 * index / math.max(1, missingNodes.length);
      rawPositions[missingNodes[index].id] = Offset(math.cos(angle) * _ringSpacing, math.sin(angle) * _ringSpacing);
    }

    final autoBounds = _boundsFor(rawPositions);
    final availableWidth = math.max(1.0, canvasSize.width - _edgePadding * 2);
    final availableHeight = math.max(1.0, canvasSize.height - _edgePadding * 2);
    final fitScale = math.min(
      1.0,
      math.min(
        availableWidth / math.max(1.0, autoBounds.width),
        availableHeight / math.max(1.0, autoBounds.height),
      ),
    );
    final autoCenter = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final autoShift = autoCenter - autoBounds.center * fitScale;

    final workingPositions = <int, Offset>{};
    for (final entry in rawPositions.entries) {
      final node = _nodeById(entry.key);
      final position = entry.value * fitScale + autoShift;
      workingPositions[entry.key] = node == null ? position : clampPosition(position, node);
    }

    for (final node in nodes) {
      if (_hasSavedPosition(node)) {
        workingPositions[node.id] = clampPosition(Offset(node.positionX!, node.positionY!), node);
      }
    }

    for (final entry in workingPositions.entries) {
      positions[entry.key] = entry.value;
    }
    graphBounds = _boundsFor(positions);
  }

  KnowledgeNode? _nodeById(int id) {
    for (final node in nodes) {
      if (node.id == id) {
        return node;
      }
    }
    return null;
  }

  bool _hasSavedPosition(KnowledgeNode node) {
    if (node.positionX == null || node.positionY == null) {
      return false;
    }
    if (node.positionX == 0 && node.positionY == 0) {
      return false;
    }
    final legacySeedX = {-240.0, -80.0, 80.0, 240.0};
    if (node.positionY == 160.0 && legacySeedX.contains(node.positionX)) {
      return false;
    }
    return true;
  }

  Rect _boundsFor(Map<int, Offset> rawPositions) {
    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;

    for (final node in nodes) {
      final position = rawPositions[node.id];
      if (position == null) {
        continue;
      }
      final size = sizeFor(node);
      left = math.min(left, position.dx - size.width / 2);
      top = math.min(top, position.dy - size.height / 2);
      right = math.max(right, position.dx + size.width / 2);
      bottom = math.max(bottom, position.dy + size.height / 2);
    }

    if (left == double.infinity) {
      return Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

class _EdgePainter extends CustomPainter {
  const _EdgePainter({
    required this.nodes,
    required this.positions,
    required this.focusedNodeId,
    required this.hoveredNodeId,
  });

  final List<KnowledgeNode> nodes;
  final Map<int, Offset> positions;
  final int? focusedNodeId;
  final int? hoveredNodeId;

  @override
  void paint(Canvas canvas, Size size) {
    final byId = {for (final node in nodes) node.id: node};
    for (final node in nodes) {
      if (node.parentId == null || positions[node.parentId] == null || positions[node.id] == null) {
        continue;
      }
      final from = positions[node.parentId]!;
      final to = positions[node.id]!;
      final highlighted = hoveredNodeId == node.id || hoveredNodeId == node.parentId || focusedNodeId == node.id || focusedNodeId == node.parentId;
      final dimmed = focusedNodeId != null && !highlighted && byId[focusedNodeId]?.parentId != node.id;
      final paint = Paint()
        ..color = highlighted ? MindVaultColors.primary : MindVaultColors.border.withValues(alpha: dimmed ? 0.35 : 1)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final vector = to - from;
      final distance = vector.distance;
      final perpendicular = distance == 0 ? Offset.zero : Offset(-vector.dy / distance, vector.dx / distance);
      final curve = perpendicular * math.min(72, distance * 0.16);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(
          from.dx + vector.dx * 0.34 + curve.dx,
          from.dy + vector.dy * 0.34 + curve.dy,
          from.dx + vector.dx * 0.66 + curve.dx,
          from.dy + vector.dy * 0.66 + curve.dy,
          to.dx,
          to.dy,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.positions != positions ||
        oldDelegate.focusedNodeId != focusedNodeId ||
        oldDelegate.hoveredNodeId != hoveredNodeId;
  }
}

class _KnowledgeGraphNode extends StatelessWidget {
  const _KnowledgeGraphNode({
    required this.node,
    required this.root,
    required this.selected,
    required this.dimmed,
    required this.layoutLocked,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondaryTapDown,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onHover,
  });

  final KnowledgeNode node;
  final bool root;
  final bool selected;
  final bool dimmed;
  final bool layoutLocked;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final ValueChanged<TapDownDetails> onSecondaryTapDown;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onSecondaryTapDown: onSecondaryTapDown,
      onPanStart: layoutLocked ? null : (_) => onDragStart(),
      onPanUpdate: layoutLocked ? null : (details) => onDragUpdate(details.delta),
      onPanEnd: layoutLocked ? null : (_) => onDragEnd(),
      onPanCancel: layoutLocked ? null : onDragEnd,
      child: MouseRegion(
        cursor: layoutLocked ? SystemMouseCursors.basic : SystemMouseCursors.grab,
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: AnimatedScale(
          scale: selected ? 1.1 : 1,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: dimmed ? 0.2 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: root ? 140 : 128,
              height: root ? 52 : 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: root ? const Color(0xFF1F2937) : selected ? MindVaultColors.selected : MindVaultColors.surface,
                borderRadius: BorderRadius.circular(root ? 16 : 14),
                border: root ? null : Border.all(color: selected ? MindVaultColors.primary : MindVaultColors.border),
                boxShadow: [
                  BoxShadow(
                    color: selected ? MindVaultColors.primary.withValues(alpha: 0.20) : Colors.black.withValues(alpha: root ? 0.08 : 0.04),
                    blurRadius: selected ? 16 : 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  node.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: root ? Colors.white : MindVaultColors.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
