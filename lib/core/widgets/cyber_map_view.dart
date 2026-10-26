import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../models/node_user.dart';
import 'location_pin_marker.dart';

class CyberMapView extends StatefulWidget {
  final NodeUser currentUser;
  final List<NodeUser> connectedNodes;
  final ValueChanged<NodeUser>? onNodeSelected;

  const CyberMapView({
    super.key,
    required this.currentUser,
    required this.connectedNodes,
    this.onNodeSelected,
  });

  @override
  State<CyberMapView> createState() => _CyberMapViewState();
}

class _CyberMapViewState extends State<CyberMapView> with SingleTickerProviderStateMixin {
  final TransformationController _transformController = TransformationController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = max(constraints.maxWidth, 600.0);
        final height = max(constraints.maxHeight, 900.0);

        // Center position for "You"
        final centerX = width * 0.50;
        final centerY = height * 0.48;

        // Visual layout relative to center, matching Home.jpg
        final nodePositions = <String, Offset>{
          widget.currentUser.id: Offset(centerX, centerY),
        };

        if (widget.connectedNodes.isNotEmpty) {
          // Alex: top left
          if (widget.connectedNodes.isNotEmpty) {
            nodePositions[widget.connectedNodes[0].id] =
                Offset(centerX - width * 0.25, centerY - height * 0.24);
          }
          // Emma: top right
          if (widget.connectedNodes.length > 1) {
            nodePositions[widget.connectedNodes[1].id] =
                Offset(centerX + width * 0.28, centerY - height * 0.15);
          }
          // Jessica: bottom left
          if (widget.connectedNodes.length > 2) {
            nodePositions[widget.connectedNodes[2].id] =
                Offset(centerX - width * 0.30, centerY + height * 0.08);
          }
          // Liam: bottom right
          if (widget.connectedNodes.length > 3) {
            nodePositions[widget.connectedNodes[3].id] =
                Offset(centerX + width * 0.26, centerY + height * 0.22);
          }
        }

        return InteractiveViewer(
          transformationController: _transformController,
          boundaryMargin: const EdgeInsets.all(300),
          minScale: 0.7,
          maxScale: 2.2,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                // 1. Cyber Map Grid & Street Canvas
                CustomPaint(
                  size: Size(width, height),
                  painter: _CyberGridPainter(
                    pulseProgress: _pulseController,
                    nodePositions: nodePositions,
                    centerOffset: Offset(centerX, centerY),
                  ),
                ),

                // 2. Glowing Interconnection Network Beams
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(width, height),
                      painter: _NetworkBeamsPainter(
                        nodePositions: nodePositions,
                        center: Offset(centerX, centerY),
                        progress: _pulseController.value,
                      ),
                    );
                  },
                ),

                // 3. Render "You" Node Marker
                Positioned(
                  left: centerX - 55,
                  top: centerY - 55,
                  child: _buildNodeMarker(
                    node: widget.currentUser,
                    isSelf: true,
                  ),
                ),

                // 4. Render Connected Peer Node Markers
                ...widget.connectedNodes.map((node) {
                  final pos = nodePositions[node.id];
                  if (pos == null) return const SizedBox.shrink();
                  return Positioned(
                    left: pos.dx - 55,
                    top: pos.dy - 55,
                    child: _buildNodeMarker(
                      node: node,
                      isSelf: false,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNodeMarker({required NodeUser node, required bool isSelf}) {
    return GestureDetector(
      onTap: () => widget.onNodeSelected?.call(node),
      child: LocationPinMarker(
        user: node,
        isSelf: isSelf,
        isSelected: false,
        isLight: false,
      ),
    );
  }
}

/// Custom Painter drawing the dark cyber-grid & street pathways
class _CyberGridPainter extends CustomPainter {
  final Animation<double> pulseProgress;
  final Map<String, Offset> nodePositions;
  final Offset centerOffset;

  _CyberGridPainter({
    required this.pulseProgress,
    required this.nodePositions,
    required this.centerOffset,
  }) : super(repaint: pulseProgress);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark deep navy base
    final bgPaint = Paint()..color = const Color(0xFF080F21);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Isometric grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF132247).withValues(alpha: 0.5)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const gridSize = 45.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 3. Cyber streets and blocks (styled after Home.jpg)
    final blockPaint = Paint()
      ..color = const Color(0xFF0D1730)
      ..style = PaintingStyle.fill;

    final streetPaint = Paint()
      ..color = const Color(0xFF1C2D5A).withValues(alpha: 0.7)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final streetGlowPaint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.15)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw stylized city blocks
    final random = Random(42);
    for (int i = 0; i < 28; i++) {
      final bx = 40.0 + random.nextDouble() * (size.width - 120);
      final by = 40.0 + random.nextDouble() * (size.height - 120);
      final bw = 40.0 + random.nextDouble() * 70;
      final bh = 30.0 + random.nextDouble() * 60;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, bw, bh),
        const Radius.circular(6),
      );
      canvas.drawRRect(rrect, blockPaint);
    }

    // Draw major cyber transit avenues
    final path1 = Path()
      ..moveTo(0, size.height * 0.25)
      ..lineTo(size.width * 0.45, size.height * 0.35)
      ..lineTo(size.width, size.height * 0.18);

    final path2 = Path()
      ..moveTo(0, size.height * 0.75)
      ..lineTo(size.width * 0.55, size.height * 0.50)
      ..lineTo(size.width, size.height * 0.65);

    final path3 = Path()
      ..moveTo(size.width * 0.2, 0)
      ..lineTo(size.width * 0.35, size.height * 0.5)
      ..lineTo(size.width * 0.8, size.height);

    canvas.drawPath(path1, streetPaint);
    canvas.drawPath(path2, streetPaint);
    canvas.drawPath(path3, streetPaint);

    canvas.drawPath(path1, streetGlowPaint);
    canvas.drawPath(path2, streetGlowPaint);
    canvas.drawPath(path3, streetGlowPaint);
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) => true;
}

/// Custom painter drawing glowing cyan cyber network beams connecting the nodes
class _NetworkBeamsPainter extends CustomPainter {
  final Map<String, Offset> nodePositions;
  final Offset center;
  final double progress;

  _NetworkBeamsPainter({
    required this.nodePositions,
    required this.center,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodePositions.length < 2) return;

    final beamPaint = Paint()
      ..color = AppTheme.electricCyan.withValues(alpha: 0.75)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final beamGlowPaint = Paint()
      ..color = AppTheme.electricCyan.withValues(alpha: 0.35)
      ..strokeWidth = 7.0
      ..style = PaintingStyle.stroke;

    // Connect Center (You) to each other node
    final positions = nodePositions.values.toList();
    for (int i = 0; i < positions.length; i++) {
      for (int j = i + 1; j < positions.length; j++) {
        final p1 = positions[i];
        final p2 = positions[j];

        // Draw glowing network lines
        canvas.drawLine(p1, p2, beamGlowPaint);
        canvas.drawLine(p1, p2, beamPaint);

        // Draw animated traveling data packet pulse along beam
        final travelT = (progress + (i * 0.25)) % 1.0;
        final packetPos = Offset.lerp(p1, p2, travelT)!;

        final packetPaint = Paint()
          ..color = AppTheme.neonGreen
          ..style = PaintingStyle.fill;

        canvas.drawCircle(packetPos, 3.5, packetPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkBeamsPainter oldDelegate) => true;
}
