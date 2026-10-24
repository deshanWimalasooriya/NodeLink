import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/cyber_app_bar.dart';
import '../providers/node_link_provider.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _animController;
  late Animation<double> _laserAnimation;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) continue;

      // Extract 6 digits (format: 842-915, 842 - 915, 842915, nodelink:842-915, etc.) or Node key
      final digitsMatch = RegExp(r'\d{3}\s*-?\s*\d{3}|\d{6}').firstMatch(rawValue);
      String targetNodeId = '';

      if (digitsMatch != null) {
        final digits = digitsMatch.group(0)!.replaceAll(RegExp(r'\D'), '');
        if (digits.length == 6) {
          targetNodeId = digits;
        }
      }

      if (targetNodeId.isEmpty) {
        final clean = rawValue.replaceFirst('nodelink:', '').trim();
        if (clean.isNotEmpty) {
          targetNodeId = clean;
        }
      }

      if (targetNodeId.isNotEmpty) {
        setState(() {
          _isProcessing = true;
        });

        // 1. Pause camera feed
        await _scannerController.stop();

        if (!mounted) return;
        final provider = context.read<NodeLinkProvider>();

        // 2. Two-Way Simultaneous Database Write:
        // users/<user_a_id>/active_connections/<user_b_id> = true
        // users/<user_b_id>/active_connections/<user_a_id> = true
        await provider.linkDevice(targetNodeId);

        if (!mounted) return;

        // 3. Display success SnackBar
        final displayId = targetNodeId.length == 6
            ? '${targetNodeId.substring(0, 3)} - ${targetNodeId.substring(3, 6)}'
            : targetNodeId;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.neonGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Node $displayId successfully paired!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.surfaceDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.neonGreen, width: 1.5),
            ),
            duration: const Duration(seconds: 3),
          ),
        );

        // 4. Automatically route back to HomeScreen
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double scanBoxSize = 270.0;
    const double cornerRadius = 24.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. MobileScanner Camera Feed
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcodeDetected,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: AppTheme.warningRed, size: 48),
                      const SizedBox(height: 14),
                      Text(
                        'Camera access error: ${error.errorCode}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Custom Cyber Overlay with dark semi-transparent backdrop and clear cutout
          CustomPaint(
            size: Size.infinite,
            painter: _ScannerHolePainter(
              boxSize: scanBoxSize,
              borderRadius: cornerRadius,
            ),
          ),

          // 3. Center Cyber Reticle matching QR Scan .jpg reference
          Center(
            child: SizedBox(
              width: scanBoxSize,
              height: scanBoxSize,
              child: Stack(
                children: [
                  // Glassmorphic translucent border
                  Container(
                    width: scanBoxSize,
                    height: scanBoxSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(cornerRadius),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1.5,
                      ),
                      color: Colors.white.withValues(alpha: 0.03),
                    ),
                  ),

                  // Glowing electric-cyan corner brackets
                  CustomPaint(
                    size: const Size(scanBoxSize, scanBoxSize),
                    painter: _CyberCornerPainter(
                      color: AppTheme.electricCyan,
                      strokeWidth: 4.0,
                      cornerLength: 38.0,
                      radius: cornerRadius,
                    ),
                  ),

                  // Animated neon green laser scanning line
                  AnimatedBuilder(
                    animation: _laserAnimation,
                    builder: (context, child) {
                      final topOffset = _laserAnimation.value * (scanBoxSize - 20);
                      return Positioned(
                        top: topOffset,
                        left: 8,
                        right: 8,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Glowing green laser line
                            Container(
                              height: 3.0,
                              decoration: BoxDecoration(
                                color: AppTheme.neonGreen,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.neonGreen.withValues(alpha: 0.8),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: AppTheme.electricCyan.withValues(alpha: 0.5),
                                    blurRadius: 18,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                            // Trailing laser glow gradient
                            Container(
                              height: 28.0,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppTheme.neonGreen.withValues(alpha: 0.25),
                                    AppTheme.neonGreen.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. Circular Cyber Back Button matching QR Scan .jpg
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0, top: 12.0),
                child: CyberCircleIconButton(
                  icon: Icons.chevron_left_rounded,
                  iconSize: 28,
                  iconColor: Colors.white,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),

          // 5. Loading overlay when processing code
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: AppTheme.electricCyan,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Linking Node to Network...',
                      style: TextStyle(
                        color: AppTheme.electricCyan,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter to cut out the scanning square hole with a dark semi-transparent backdrop
class _ScannerHolePainter extends CustomPainter {
  final double boxSize;
  final double borderRadius;

  _ScannerHolePainter({
    required this.boxSize,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xB8070D1F);

    final screenRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);

    final cutRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: boxSize, height: boxSize),
      Radius.circular(borderRadius),
    );

    final screenPath = Path()..addRect(screenRect);
    final holePath = Path()..addRRect(cutRect);

    final combinedPath = Path.combine(PathOperation.difference, screenPath, holePath);
    canvas.drawPath(combinedPath, bgPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerHolePainter oldDelegate) =>
      oldDelegate.boxSize != boxSize || oldDelegate.borderRadius != borderRadius;
}

/// Custom painter for glowing electric-cyan corners matching QR Scan .jpg
class _CyberCornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final double radius;

  _CyberCornerPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = strokeWidth + 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    void drawCorner(Path path) {
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, paint);
    }

    // Top-Left
    final tl = Path()
      ..moveTo(-6, cornerLength)
      ..lineTo(-6, radius)
      ..arcToPoint(Offset(radius, -6), radius: Radius.circular(radius + 6))
      ..lineTo(cornerLength, -6);
    drawCorner(tl);

    // Top-Right
    final tr = Path()
      ..moveTo(size.width - cornerLength, -6)
      ..lineTo(size.width - radius, -6)
      ..arcToPoint(Offset(size.width + 6, radius), radius: Radius.circular(radius + 6))
      ..lineTo(size.width + 6, cornerLength);
    drawCorner(tr);

    // Bottom-Left
    final bl = Path()
      ..moveTo(-6, size.height - cornerLength)
      ..lineTo(-6, size.height - radius)
      ..arcToPoint(Offset(radius, size.height + 6), radius: Radius.circular(radius + 6))
      ..lineTo(cornerLength, size.height + 6);
    drawCorner(bl);

    // Bottom-Right
    final br = Path()
      ..moveTo(size.width - cornerLength, size.height + 6)
      ..lineTo(size.width - radius, size.height + 6)
      ..arcToPoint(Offset(size.width + 6, size.height - radius), radius: Radius.circular(radius + 6))
      ..lineTo(size.width + 6, size.height - cornerLength);
    drawCorner(br);
  }

  @override
  bool shouldRepaint(covariant _CyberCornerPainter oldDelegate) => false;
}
