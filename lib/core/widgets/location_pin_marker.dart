import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../models/node_user.dart';

/// Mathematically precise Teardrop Pin Path with rounded bottom tip
/// and seamless C1 tangent transitions to the top circular dome.
Path buildTeardropPinPath(double w, double h, {double tipRadius = 2.5}) {
  final path = Path();
  final r = w / 2;
  final d = (h - tipRadius - r).clamp(r * 1.05, 1000.0);

  // Tangent angle calculation
  final sinTheta = (r / d).clamp(0.0, 1.0);
  final cosTheta = math.sqrt(1.0 - sinTheta * sinTheta);

  final dx = r * sinTheta;
  final dy = r * cosTheta;

  final xRight = r + dx;
  final yRight = r + dy;
  final xLeft = r - dx;
  final yLeft = r + dy;

  final tipDx = tipRadius * cosTheta;

  // 1. Start on the left tangent line just above the rounded tip
  path.moveTo(r - tipDx, h - tipRadius * 1.4);

  // 2. Rounded bottom tip pointing downward
  path.quadraticBezierTo(r, h, r + tipDx, h - tipRadius * 1.4);

  // 3. Tangent line up right side to the circle
  path.lineTo(xRight, yRight);

  // 4. Circular top dome (sweeping counter-clockwise over the top)
  path.arcToPoint(
    Offset(xLeft, yLeft),
    radius: Radius.circular(r),
    largeArc: true,
    clockwise: false,
  );

  // 5. Tangent line down left side back to rounded tip
  path.lineTo(r - tipDx, h - tipRadius * 1.4);
  path.close();

  return path;
}

/// Custom painter for the teardrop location pin with neon glow & gradient
class LocationPinPainter extends CustomPainter {
  final Color pinColor;
  final Color glowColor;
  final bool isSelected;
  final bool isLight;

  const LocationPinPainter({
    required this.pinColor,
    required this.glowColor,
    this.isSelected = false,
    this.isLight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = buildTeardropPinPath(w, h);

    // 1. Ambient Glow / Drop Shadow
    final shadowPaint = Paint()
      ..color = glowColor.withValues(alpha: isSelected ? 0.75 : 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSelected ? 12.0 : 8.0);
    canvas.drawPath(path, shadowPaint);

    // 2. Solid Pin Body with subtle gradient
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          pinColor,
          Color.lerp(
                pinColor,
                isLight ? Colors.blue.shade900 : const Color(0xFF0A0E1A),
                0.25,
              ) ??
              pinColor,
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, bodyPaint);

    // 3. Crisp outer highlight stroke
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: isLight ? 0.6 : 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path, strokePaint);

    // 4. Ground anchor shadow dot beneath the tip
    final groundPaint = Paint()
      ..color = (isLight ? Colors.black : pinColor).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h + 1.5),
        width: 14.0,
        height: 4.0,
      ),
      groundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant LocationPinPainter oldDelegate) {
    return oldDelegate.pinColor != pinColor ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.isLight != isLight;
  }
}

/// Location Pin Marker with circular avatar window inside
/// strictly styled after modern vector map pins.
class LocationPinMarker extends StatelessWidget {
  final NodeUser user;
  final bool isSelf;
  final bool isSelected;
  final bool isLight;
  final double width;
  final double height;
  final bool showBadge;

  const LocationPinMarker({
    super.key,
    required this.user,
    required this.isSelf,
    this.isSelected = false,
    this.isLight = false,
    this.width = 46.0,
    this.height = 60.0,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    // Determine pin colors based on role and status
    final Color pinColor;
    if (isSelf) {
      pinColor = isLight ? const Color(0xFF0284C7) : const Color(0xFF00F0FF);
    } else if (isSelected) {
      pinColor = AppTheme.neonGreen;
    } else if (user.status.toLowerCase() == 'online') {
      pinColor = isLight ? const Color(0xFF059669) : AppTheme.neonGreen;
    } else {
      pinColor = isLight ? const Color(0xFF64748B) : const Color(0xFF38BDF8);
    }

    final glowColor = isSelected
        ? pinColor
        : (isSelf ? const Color(0xFF00F0FF) : pinColor);

    // Inner avatar dimensions (centered in top circular dome)
    final avatarOuterDiameter = width * 0.72; // ~33px
    final avatarTopOffset = (width - avatarOuterDiameter) / 2; // ~6.5px

    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Floating Name Badge at top of marker
          if (showBadge) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isLight
                    ? (isSelf
                        ? const Color(0xFF0284C7)
                        : Colors.white.withValues(alpha: 0.96))
                    : AppTheme.deepNavy.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isLight && !isSelf
                      ? const Color(0xFFCBD5E1)
                      : pinColor,
                  width: isSelected ? 1.6 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? pinColor.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: isLight ? 0.15 : 0.4),
                    blurRadius: isSelected ? 8 : 4,
                  ),
                ],
              ),
              child: Text(
                isSelf ? 'You' : user.name.split(' ').first,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isLight
                      ? (isSelf ? Colors.white : const Color(0xFF0F172A))
                      : (isSelf || isSelected ? pinColor : Colors.white),
                  letterSpacing: 0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 3),
          ],

          // 2. The Location Pin with Circular Avatar cutout
          SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // A. The Teardrop Pin Shape (Custom Paint)
                CustomPaint(
                  size: Size(width, height),
                  painter: LocationPinPainter(
                    pinColor: pinColor,
                    glowColor: glowColor,
                    isSelected: isSelected,
                    isLight: isLight,
                  ),
                ),

                // B. The White Circular Ring & Avatar Window
                Positioned(
                  top: avatarTopOffset,
                  child: Container(
                    width: avatarOuterDiameter,
                    height: avatarOuterDiameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.white,
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 3.5,
                          offset: const Offset(0, 1.2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildAvatarContent(pinColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent(Color iconColor) {
    final photoUrl = user.profilePicUrl?.trim() ?? '';
    final assetPath = user.avatarPath.trim();

    // 1. Network / Cloud Storage image
    if (photoUrl.startsWith('http')) {
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildSilhouetteFallback(iconColor),
      );
    }

    // 2. Base64 encoded image
    if (photoUrl.contains('data:image') || photoUrl.length > 100) {
      try {
        final base64String = photoUrl.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildSilhouetteFallback(iconColor),
        );
      } catch (_) {
        return _buildSilhouetteFallback(iconColor);
      }
    }

    // 3. Local asset image (e.g. nuwan.jpg)
    if (assetPath.isNotEmpty &&
        (assetPath.endsWith('.jpg') ||
            assetPath.endsWith('.jpeg') ||
            assetPath.endsWith('.png'))) {
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildSilhouetteFallback(iconColor),
      );
    }

    // 4. Default: White background with colored person silhouette
    // Exactly matches the user's reference image!
    return _buildSilhouetteFallback(iconColor);
  }

  Widget _buildSilhouetteFallback(Color iconColor) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: width * 0.52,
        color: iconColor,
      ),
    );
  }
}
