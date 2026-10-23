import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarkerHelper {
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Generate custom marker for "You" matching Welcome Home.jpg
  static Future<BitmapDescriptor> getYouMarker() async {
    const key = 'you_marker';
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      const size = Size(180, 220);

      // 1. Top "You" badge pill
      final badgePaint = Paint()..color = const Color(0xFF1C2541);
      final badgeBorder = Paint()
        ..color = const Color(0xFF00F0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final badgeRRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(45, 10, 90, 36),
        const Radius.circular(18),
      );
      canvas.drawRRect(badgeRRect, badgePaint);
      canvas.drawRRect(badgeRRect, badgeBorder);

      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'You',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(size.width / 2 - textPainter.width / 2, 17),
      );

      // 2. Concentric glowing rings
      final center = Offset(size.width / 2, 110);
      final ring1 = Paint()
        ..color = const Color(0xFF00F0FF).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawCircle(center, 55, ring1);

      final ring2 = Paint()
        ..color = const Color(0xFF39FF14).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawCircle(center, 44, ring2);

      // 3. Center avatar circle & border
      final bgPaint = Paint()..color = const Color(0xFF0B132B);
      canvas.drawCircle(center, 34, bgPaint);

      final circleBorder = Paint()
        ..color = const Color(0xFF00F0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      canvas.drawCircle(center, 34, circleBorder);

      // 4. Stylized user silhouette
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.person.codePoint),
          style: TextStyle(
            fontSize: 42,
            fontFamily: Icons.person.fontFamily,
            package: Icons.person.fontPackage,
            color: Colors.white70,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(
        canvas,
        Offset(center.dx - iconPainter.width / 2, center.dy - iconPainter.height / 2),
      );

      // 5. Pin arrow at bottom
      final arrowPath = Path()
        ..moveTo(center.dx - 10, center.dy + 34)
        ..lineTo(center.dx + 10, center.dy + 34)
        ..lineTo(center.dx, center.dy + 48)
        ..close();
      canvas.drawPath(arrowPath, Paint()..color = const Color(0xFF00F0FF));

      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final descriptor = BitmapDescriptor.bytes(bytes);
      _cache[key] = descriptor;
      return descriptor;
    } catch (e) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    }
  }

  /// Generate custom marker for neighbor matching Home.jpg
  static Future<BitmapDescriptor> getNeighborMarker({
    required String name,
    required String avatarAsset,
    bool isOnline = true,
  }) async {
    final key = 'neighbor_${name}_$isOnline';
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      const size = Size(180, 220);

      // 1. Name badge at top
      final badgePaint = Paint()..color = const Color(0xFF1C2541);
      final badgeBorder = Paint()
        ..color = isOnline ? const Color(0xFF39FF14) : const Color(0xFF00F0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final badgeRRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(30, 10, 120, 36),
        const Radius.circular(18),
      );
      canvas.drawRRect(badgeRRect, badgePaint);
      canvas.drawRRect(badgeRRect, badgeBorder);

      final textPainter = TextPainter(
        text: TextSpan(
          text: name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(size.width / 2 - textPainter.width / 2, 18),
      );

      // 2. Concentric glowing rings
      final center = Offset(size.width / 2, 110);
      final glowColor = isOnline ? const Color(0xFF39FF14) : const Color(0xFF00F0FF);

      final ring1 = Paint()
        ..color = glowColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawCircle(center, 55, ring1);

      final ring2 = Paint()
        ..color = glowColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawCircle(center, 44, ring2);

      // 3. Draw avatar photo inside circle
      bool avatarDrawn = false;
      try {
        final data = await rootBundle.load(avatarAsset);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: 70,
          targetHeight: 70,
        );
        final frameInfo = await codec.getNextFrame();
        final uiImage = frameInfo.image;

        canvas.save();
        final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: 34));
        canvas.clipPath(clipPath);
        canvas.drawImage(
          uiImage,
          Offset(center.dx - uiImage.width / 2, center.dy - uiImage.height / 2),
          Paint(),
        );
        canvas.restore();
        avatarDrawn = true;
      } catch (_) {
        avatarDrawn = false;
      }

      if (!avatarDrawn) {
        final bgPaint = Paint()..color = const Color(0xFF0B132B);
        canvas.drawCircle(center, 34, bgPaint);
        final initialPainter = TextPainter(
          text: TextSpan(
            text: name.isNotEmpty ? name[0] : '?',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        initialPainter.paint(
          canvas,
          Offset(center.dx - initialPainter.width / 2, center.dy - initialPainter.height / 2),
        );
      }

      final circleBorder = Paint()
        ..color = glowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      canvas.drawCircle(center, 34, circleBorder);

      // Pin arrow
      final arrowPath = Path()
        ..moveTo(center.dx - 10, center.dy + 34)
        ..lineTo(center.dx + 10, center.dy + 34)
        ..lineTo(center.dx, center.dy + 48)
        ..close();
      canvas.drawPath(arrowPath, Paint()..color = glowColor);

      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final descriptor = BitmapDescriptor.bytes(bytes);
      _cache[key] = descriptor;
      return descriptor;
    } catch (e) {
      return BitmapDescriptor.defaultMarkerWithHue(
        isOnline ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueAzure,
      );
    }
  }
}
