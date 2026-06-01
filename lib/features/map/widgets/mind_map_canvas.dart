import 'package:flutter/material.dart';
import 'package:dendrite/core/db/database.dart';

class MindMapCanvas extends StatefulWidget {
  final List<Message> nodes;
  final Function(String nodeId) onNodeTap;

  const MindMapCanvas({
    super.key,
    required this.nodes,
    required this.onNodeTap,
  });

  @override
  State<MindMapCanvas> createState() => _MindMapCanvasState();
}

class _MindMapCanvasState extends State<MindMapCanvas> {
  Offset _offset = Offset.zero;
  final double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _offset += details.delta;
        });
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: TreeGraphPainter(
          nodes: widget.nodes,
          offset: _offset,
          scale: _scale,
          onNodeTap: widget.onNodeTap,
        ),
      ),
    );
  }
}

class TreeGraphPainter extends CustomPainter {
  final List<Message> nodes;
  final Offset offset;
  final double scale;
  final Function(String nodeId) onNodeTap;

  TreeGraphPainter({
    required this.nodes,
    required this.offset,
    required this.scale,
    required this.onNodeTap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = const Color(0xFF10A37F)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final paintCircle = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;

    final paintCircleBorder = Paint()
      ..color = const Color(0xFF10A37F)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw tree lines and nodes
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      // Compute layout coordinates (simplified top-down grid for demo)
      final x = size.width / 2 + offset.dx + (i * 40 - (nodes.length * 20));
      final y = 80.0 + offset.dy + (i * 80);
      final center = Offset(x, y);

      canvas.drawCircle(center, 20.0 * scale, paintCircle);
      canvas.drawCircle(center, 20.0 * scale, paintCircleBorder);

      if (node.parentId != null) {
        // Draw dashed connector line up to parent
        final parentY = y - 80.0;
        canvas.drawLine(Offset(x, parentY + 20), Offset(x, y - 20), paintLine);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
