import 'package:flutter/material.dart';
import 'package:dendrite/core/db/database.dart';

class MindMapCanvas extends StatefulWidget {
  final List<Message> nodes;
  final String activeNodeId;
  final bool isDarkMode;
  final Function(String nodeId) onNodeTap;

  const MindMapCanvas({
    super.key,
    required this.nodes,
    required this.activeNodeId,
    required this.isDarkMode,
    required this.onNodeTap,
  });

  @override
  State<MindMapCanvas> createState() => _MindMapCanvasState();
}

class _MindMapCanvasState extends State<MindMapCanvas> {
  final TransformationController _controller = TransformationController();
  String? _lastCenteredNodeId;

  @override
  void initState() {
    super.initState();
    // Center on active node after first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centerOnActiveNode();
    });
  }

  @override
  void didUpdateWidget(covariant MindMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-center when active node changes or first time rendering
    if (widget.activeNodeId != _lastCenteredNodeId && widget.nodes.isNotEmpty) {
      _centerOnActiveNode();
    }
  }

  void _centerOnActiveNode() {
    if (widget.nodes.isEmpty) return;

    // Compute coordinates (same logic as build)
    const double vertSpacing = 120.0;
    const double horizSpacing = 100.0;

    final Map<String, List<String>> childrenMap = {};
    String? rootId;
    for (final node in widget.nodes) {
      if (node.parentId == null) {
        rootId = node.id;
      } else {
        childrenMap.putIfAbsent(node.parentId!, () => []).add(node.id);
      }
    }
    rootId ??= widget.nodes.first.id;

    final Map<String, Offset> coordinates = {};
    final Map<int, List<String>> nodesAtDepth = {};
    void computeDepths(String id, int depth) {
      nodesAtDepth.putIfAbsent(depth, () => []).add(id);
      for (final child in childrenMap[id] ?? []) {
        computeDepths(child, depth + 1);
      }
    }
    computeDepths(rootId, 0);

    nodesAtDepth.forEach((depth, idList) {
      final totalW = (idList.length - 1) * horizSpacing;
      final startX = -totalW / 2;
      for (int i = 0; i < idList.length; i++) {
        final id = idList[i];
        coordinates[id] = Offset(startX + i * horizSpacing, depth * vertSpacing + 60.0);
      }
    });

    double minX = -200.0, maxX = 200.0, minY = 0.0, maxY = 500.0;
    for (final pos in coordinates.values) {
      if (pos.dx < minX) minX = pos.dx;
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dy > maxY) maxY = pos.dy;
    }

    final Offset origin = Offset(-minX + 200.0, 40.0);
    final activePos = coordinates[widget.activeNodeId];
    if (activePos == null) return;

    final absolutePos = activePos + origin;
    final screenSize = MediaQuery.of(context).size;
    final scale = _controller.value.getMaxScaleOnAxis();

    // Translate so active node is centered on screen
    final dx = screenSize.width / 2 / scale - absolutePos.dx;
    final dy = screenSize.height / 2 / scale - absolutePos.dy;

    _controller.value = Matrix4.identity()
      ..scale(scale, scale)
      ..translate(dx, dy);

    _lastCenteredNodeId = widget.activeNodeId;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) {
      return Center(
        child: Text(
          '🌿 暂无对话树结构数据',
          style: TextStyle(color: widget.isDarkMode ? Colors.grey : const Color(0xFF8E8E8F), fontSize: 13),
        ),
      );
    }

    // Horizontal and vertical spacing constants
    const double vertSpacing = 120.0;
    const double horizSpacing = 100.0;

    // 1. Build tree hierarchy by scanning parenthood relations
    final Map<String, List<String>> childrenMap = {};
    final Map<String, String?> parentMap = {};
    String? rootId;

    for (final node in widget.nodes) {
      parentMap[node.id] = node.parentId;
      if (node.parentId == null) {
        rootId = node.id;
      } else {
        childrenMap.putIfAbsent(node.parentId!, () => []).add(node.id);
      }
    }

    // Fallback if no explicit root is null-parented
    rootId ??= widget.nodes.first.id;

    // 2. Assign coordinates using hierarchical DFS
    final Map<String, Offset> coordinates = {};
    final Map<int, List<String>> nodesAtDepth = {};

    void computeDepths(String id, int depth) {
      nodesAtDepth.putIfAbsent(depth, () => []).add(id);
      final children = childrenMap[id] ?? [];
      for (final child in children) {
        computeDepths(child, depth + 1);
      }
    }

    computeDepths(rootId, 0);

    // Position each node horizontally centered per level
    nodesAtDepth.forEach((depth, idList) {
      final totalW = (idList.length - 1) * horizSpacing;
      final startX = -totalW / 2;
      for (int i = 0; i < idList.length; i++) {
        final id = idList[i];
        final x = startX + i * horizSpacing;
        final y = depth * vertSpacing + 60.0;
        coordinates[id] = Offset(x, y);
      }
    });

    // Determine coordinate bounding boxes to set canvas size
    double minX = -200.0;
    double maxX = 200.0;
    double minY = 0.0;
    double maxY = 500.0;

    for (final pos in coordinates.values) {
      if (pos.dx < minX) minX = pos.dx;
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dy > maxY) maxY = pos.dy;
    }

    // Expand bounding box with margins
    final double canvasWidth = (maxX - minX) + 400.0;
    final double canvasHeight = (maxY - minY) + 200.0;
    final Offset origin = Offset(-minX + 200.0, 40.0);

    final canvasBg = widget.isDarkMode ? const Color(0xFF0D0D0D) : const Color(0xFFF9F9F9);

    return Container(
      color: canvasBg,
      child: InteractiveViewer(
        transformationController: _controller,
        maxScale: 2.5,
        minScale: 0.5,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(500),
        child: SizedBox(
          width: canvasWidth,
          height: canvasHeight,
          child: Stack(
            children: [
                // Paint linking branches
                Positioned.fill(
                  child: CustomPaint(
                    painter: LinkPainter(
                      nodes: widget.nodes,
                      coordinates: coordinates,
                      origin: origin,
                      childrenMap: childrenMap,
                      activeNodeId: widget.activeNodeId,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                ),
                
                // Positioned node widgets
                ...widget.nodes.map((node) {
                  final pos = coordinates[node.id] ?? Offset.zero;
                  final absolutePos = pos + origin;
                  final isActive = node.id == widget.activeNodeId;
                  final isUser = node.role == 'user';

                  final circleBg = isActive
                      ? const Color(0xFF10A37F)
                      : (isUser
                          ? (widget.isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA))
                          : (widget.isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF)));
                  final circleBorder = isActive
                      ? const Color(0xFF19C37D)
                      : (node.isBookmarked
                          ? const Color(0xFFFFB800)
                          : (widget.isDarkMode ? const Color(0xFF2F2F2F) : const Color(0xFFCCCCCC)));

                  return Positioned(
                    left: absolutePos.dx - 22,
                    top: absolutePos.dy - 22,
                    child: GestureDetector(
                      onTap: () => widget.onNodeTap(node.id),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: circleBg,
                              shape: BoxShape.circle,
                              border: Border.all(color: circleBorder, width: 2.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            alignment: Alignment.center,
                            child: node.isBookmarked
                                ? const Icon(Icons.star, color: Color(0xFFFFB800), size: 20)
                                : Text(
                                    isUser ? 'U' : 'AI',
                                    style: TextStyle(
                                      color: isActive ? Colors.white : (widget.isDarkMode ? Colors.white : Colors.black87),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.isDarkMode
                                  ? const Color(0xFF121212).withOpacity(0.85)
                                  : const Color(0xFFFFFFFF).withOpacity(0.95),
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFF10A37F)
                                    : (widget.isDarkMode ? const Color(0xFF262626) : const Color(0xFFE2E2E2)),
                                width: 0.8,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                if (!widget.isDarkMode)
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  )
                              ],
                            ),
                            constraints: const BoxConstraints(maxWidth: 84),
                            child: Text(
                              node.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isActive
                                    ? const Color(0xFF10A37F)
                                    : (widget.isDarkMode ? const Color(0xFF8E8E8F) : const Color(0xFF555555)),
                                fontSize: 9.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
  }
}

class LinkPainter extends CustomPainter {
  final List<Message> nodes;
  final Map<String, Offset> coordinates;
  final Offset origin;
  final Map<String, List<String>> childrenMap;
  final String activeNodeId;
  final bool isDarkMode;

  LinkPainter({
    required this.nodes,
    required this.coordinates,
    required this.origin,
    required this.childrenMap,
    required this.activeNodeId,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final activePath = _getActiveLineage();

    final normalPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF262626) : const Color(0xFFE2E2E2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final activePaint = Paint()
      ..color = const Color(0xFF10A37F)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    coordinates.forEach((parentId, parentPos) {
      final children = childrenMap[parentId] ?? [];
      for (final childId in children) {
        final childPos = coordinates[childId];
        if (childPos != null) {
          final start = parentPos + origin;
          final end = childPos + origin;

          // Check if link is part of active dialogue pathway
          final isLinkActive = activePath.contains(parentId) && activePath.contains(childId);
          final paint = isLinkActive ? activePaint : normalPaint;

          // Draw cubic curve line for dynamic tree connection
          final path = Path()
            ..moveTo(start.dx, start.dy)
            ..cubicTo(
              start.dx,
              (start.dy + end.dy) / 2,
              end.dx,
              (start.dy + end.dy) / 2,
              end.dx,
              end.dy,
            );

          canvas.drawPath(path, paint);
        }
      }
    });
  }

  Set<String> _getActiveLineage() {
    final Set<String> path = {};
    String? currentId = activeNodeId;
    while (currentId != null) {
      path.add(currentId);
      final node = _findNode(currentId);
      currentId = node?.parentId;
    }
    return path;
  }

  Message? _findNode(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
