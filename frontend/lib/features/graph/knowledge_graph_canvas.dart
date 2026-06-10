import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api/api_models.dart';

class KnowledgeGraphCanvas extends StatefulWidget {
  const KnowledgeGraphCanvas({
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

  final List<KnowledgeNode> nodes;
  final KnowledgeNode? selectedNode;
  final ValueChanged<KnowledgeNode> onNodeTap;
  final ValueChanged<KnowledgeNode> onNodeDoubleTap;
  final void Function(KnowledgeNode node, Offset position) onNodePositionChanged;
  final void Function(KnowledgeNode node, Offset position) onNodePositionCommitted;
  final VoidCallback onCanvasTap;
  final VoidCallback onCanvasDoubleTap;

  @override
  State<KnowledgeGraphCanvas> createState() => _KnowledgeGraphCanvasState();
}

class _KnowledgeGraphCanvasState extends State<KnowledgeGraphCanvas> {
  final _transformationController = TransformationController();
  int? _focusedNodeId;
  int? _hoveredNodeId;
  int? _draggingNodeId;
  Offset? _lastDragPosition;
  double _dragDistance = 0;
  String? _canvasViewKey;

  @override
  void dispose() {
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

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() => _focusedNodeId = null);
            widget.onCanvasTap();
          },
          onDoubleTap: () {
            setState(() => _focusedNodeId = null);
            widget.onCanvasDoubleTap();
          },
          child: Listener(
            onPointerSignal: (event) => _handlePointerSignal(event, canvasSize, viewportSize, layout.graphBounds),
            child: InteractiveViewer(
              transformationController: _transformationController,
              constrained: false,
              alignment: Alignment.topLeft,
              boundaryMargin: EdgeInsets.zero,
              minScale: minScale,
              maxScale: 3.5,
              scaleEnabled: false,
              trackpadScrollCausesScale: true,
              panEnabled: _draggingNodeId == null,
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
                          onTap: () => widget.onNodeTap(node),
                          onDoubleTap: () {
                            setState(() => _focusedNodeId = node.id);
                            widget.onNodeDoubleTap(node);
                          },
                          onDragStart: () {
                            setState(() {
                              _draggingNodeId = node.id;
                              _lastDragPosition = layout.positions[node.id];
                              _dragDistance = 0;
                            });
                            widget.onNodeTap(node);
                          },
                          onDragUpdate: (delta) {
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
        );
      },
    );
  }

  void _handlePointerSignal(PointerSignalEvent event, Size canvasSize, Size viewportSize, Rect graphBounds) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) {
      return;
    }

    final current = _transformationController.value;
    final oldScale = current.getMaxScaleOnAxis();
    final isZoomOut = event.scrollDelta.dy > 0;
    final zoomFactor = event.scrollDelta.dy < 0 ? 1.12 : 0.88;
    final minScale = _minCanvasScale(canvasSize, viewportSize);
    final rawScale = oldScale * zoomFactor;
    final newScale = rawScale.clamp(minScale, 3.5).toDouble();
    if ((newScale - oldScale).abs() < 0.0001) {
      return;
    }

    if (isZoomOut && (newScale - minScale).abs() < 0.0001) {
      _setCanvasTransformExact(newScale, _centerGraphOffsetAtScale(graphBounds, viewportSize, newScale));
      return;
    }

    final mousePosition = event.localPosition;
    final translation = current.getTranslation();
    final oldOffset = Offset(translation.x, translation.y);
    final graphPoint = (mousePosition - oldOffset) / oldScale;
    final newOffset = mousePosition - graphPoint * newScale;

    _setCanvasTransformExact(newScale, newOffset);
  }

  Offset _centerGraphOffsetAtScale(Rect graphBounds, Size viewportSize, double scale) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0 || graphBounds.width <= 0 || graphBounds.height <= 0) {
      return Offset.zero;
    }
    final viewportCenter = Offset(viewportSize.width / 2, viewportSize.height / 2);
    return viewportCenter - graphBounds.center * scale;
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
      return 0.2;
    }
    return math.min(
      viewportSize.width / canvasSize.width,
      viewportSize.height / canvasSize.height,
    ).clamp(0.2, 1.0).toDouble();
  }

  void _setCanvasTransform(Size canvasSize, Size viewportSize, double scale, Offset translation) {
    final scaledWidth = canvasSize.width * scale;
    final scaledHeight = canvasSize.height * scale;
    final tx = scaledWidth <= viewportSize.width
        ? (viewportSize.width - scaledWidth) / 2
        : translation.dx.clamp(viewportSize.width - scaledWidth, 0).toDouble();
    final ty = scaledHeight <= viewportSize.height
        ? (viewportSize.height - scaledHeight) / 2
        : translation.dy.clamp(viewportSize.height - scaledHeight, 0).toDouble();
    final matrix = Matrix4.identity();
    matrix.storage[0] = scale;
    matrix.storage[5] = scale;
    matrix.storage[12] = tx;
    matrix.storage[13] = ty;
    _transformationController.value = matrix;
  }

  void _setCanvasTransformExact(double scale, Offset translation) {
    final matrix = Matrix4.identity();
    matrix.storage[0] = scale;
    matrix.storage[5] = scale;
    matrix.storage[12] = translation.dx;
    matrix.storage[13] = translation.dy;
    _transformationController.value = matrix;
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
    required this.onTap,
    required this.onDoubleTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onHover,
  });

  final KnowledgeNode node;
  final bool root;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
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
      onPanStart: (_) => onDragStart(),
      onPanUpdate: (details) => onDragUpdate(details.delta),
      onPanEnd: (_) => onDragEnd(),
      onPanCancel: onDragEnd,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
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
