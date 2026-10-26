import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/cyber_app_bar.dart';
import '../providers/node_link_provider.dart';
import '../services/firebase_sync_service.dart';

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
  bool _isTorchOn = false;

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

  Future<void> _pickImageFromGallery() async {
    if (_isProcessing) return;
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final barcodeCapture = await _scannerController.analyzeImage(image.path);
      if (barcodeCapture != null && barcodeCapture.barcodes.isNotEmpty) {
        await _handleBarcodeDetected(barcodeCapture);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No Node ID QR code found in selected image.'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to read image: $e'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
    }
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) continue;

      // Extract 16-character alphanumeric cryptographic string (or legacy 6-digit Node ID)
      String targetNodeId = '';
      final clean = rawValue.replaceFirst('nodelink:', '').trim();
      final hex16Match = RegExp(r'[a-zA-Z0-9]{16}').firstMatch(clean);

      if (hex16Match != null) {
        targetNodeId = hex16Match.group(0)!;
      } else {
        final digitsMatch = RegExp(r'\d{3}\s*-?\s*\d{3}|\d{6}').firstMatch(rawValue);
        if (digitsMatch != null) {
          final digits = digitsMatch.group(0)!.replaceAll(RegExp(r'\D'), '');
          if (digits.length == 6) {
            targetNodeId = digits;
          }
        }
      }

      if (targetNodeId.isEmpty && clean.isNotEmpty) {
        targetNodeId = clean;
      }

      if (targetNodeId.isNotEmpty) {
        setState(() {
          _isProcessing = true;
        });

        // 1. Pause camera feed
        await _scannerController.stop();

        if (!mounted) return;
        final provider = context.read<NodeLinkProvider>();
        final myNodeId = provider.currentUser.id;
        final myUsername = provider.currentUser.name;

        // Prevent scanning own node
        if (targetNodeId == myNodeId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot link your own Node ID!'),
              backgroundColor: AppTheme.warningRed,
            ),
          );
          setState(() => _isProcessing = false);
          await _scannerController.start();
          return;
        }

        // 2. Handshake Phase 1: Write connection request to target's pending_requests node
        final requestSent = await FirebaseSyncService.sendConnectionRequest(
          targetNodeId: targetNodeId,
          myNodeId: myNodeId,
          myUsername: myUsername,
        );

        if (!mounted) return;

        // 3. UI Feedback: Connection request sent! Waiting for approval.
        if (requestSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection request sent! Waiting for approval.'),
              backgroundColor: AppTheme.electricCyan,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
          // Pop the scanner screen
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send connection request. Please try again.'),
              backgroundColor: AppTheme.warningRed,
            ),
          );
          setState(() => _isProcessing = false);
          await _scannerController.start();
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double scanBoxSize = 270.0;
    const double cornerRadius = 24.0;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final primaryAccent = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color ??
                              (isLight ? AppTheme.lightTextPrimary : Colors.white),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Dynamic Frosted Glass Overlay with clear scanning cutout
          ClipPath(
            clipper: _ScannerHoleClipper(
              boxSize: scanBoxSize,
              borderRadius: cornerRadius,
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: isLight
                    ? Colors.white.withValues(alpha: 0.70)
                    : const Color(0xB8070D1F),
              ),
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
                        color: isLight
                            ? primaryAccent.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.22),
                        width: 1.5,
                      ),
                      color: isLight
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.03),
                    ),
                  ),

                  // Glowing corner brackets
                  CustomPaint(
                    size: const Size(scanBoxSize, scanBoxSize),
                    painter: _CyberCornerPainter(
                      color: isLight ? const Color(0xFF0284C7) : AppTheme.electricCyan,
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
                                    color: primaryAccent.withValues(alpha: 0.5),
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

          // 4. "Scan a Node ID" Instruction Text
          Positioned(
            top: MediaQuery.of(context).padding.top + 54,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Scan a Node ID',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.textTheme.bodyLarge?.color ??
                        (isLight ? AppTheme.lightTextPrimary : Colors.white),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Align QR code within the frame to link',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75) ??
                        (isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),

          // 5. Flashlight and Gallery Toggle Buttons
          Positioned(
            bottom: 44,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildScannerToggle(
                  context,
                  icon: _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  label: 'Flashlight',
                  isActive: _isTorchOn,
                  isLight: isLight,
                  onTap: () async {
                    await _scannerController.toggleTorch();
                    setState(() {
                      _isTorchOn = !_isTorchOn;
                    });
                  },
                ),
                const SizedBox(width: 36),
                _buildScannerToggle(
                  context,
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  isActive: false,
                  isLight: isLight,
                  onTap: _pickImageFromGallery,
                ),
              ],
            ),
          ),

          // 6. Circular Cyber Back Button
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0, top: 12.0),
                child: CyberCircleIconButton(
                  icon: Icons.chevron_left_rounded,
                  iconSize: 28,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),

          // 7. Loading overlay when processing code
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: primaryAccent,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Linking Node to Network...',
                      style: TextStyle(
                        color: primaryAccent,
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

  Widget _buildScannerToggle(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isLight,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ??
        (isLight ? AppTheme.lightTextPrimary : Colors.white);
    final activeColor = theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? activeColor.withValues(alpha: 0.25)
                      : (isLight
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppTheme.surfaceDark.withValues(alpha: 0.7)),
                  border: Border.all(
                    color: isActive
                        ? activeColor
                        : (isLight
                            ? AppTheme.lightBorder
                            : AppTheme.electricCyan.withValues(alpha: 0.3)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isLight
                          ? const Color(0xFF0F172A).withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 24,
                    color: isActive ? activeColor : textColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom clipper to cut out the scanning square hole leaving the camera view clear
class _ScannerHoleClipper extends CustomClipper<Path> {
  final double boxSize;
  final double borderRadius;

  _ScannerHoleClipper({
    required this.boxSize,
    required this.borderRadius,
  });

  @override
  Path getClip(Size size) {
    final screenRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);

    final cutRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: boxSize, height: boxSize),
      Radius.circular(borderRadius),
    );

    final screenPath = Path()..addRect(screenRect);
    final holePath = Path()..addRRect(cutRect);

    return Path.combine(PathOperation.difference, screenPath, holePath);
  }

  @override
  bool shouldReclip(covariant _ScannerHoleClipper oldClipper) =>
      oldClipper.boxSize != boxSize || oldClipper.borderRadius != borderRadius;
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
