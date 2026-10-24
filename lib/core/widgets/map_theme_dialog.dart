import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../../providers/node_link_provider.dart';

class MapThemeDialog extends StatelessWidget {
  const MapThemeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => const MapThemeDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NodeLinkProvider>();
    final isLight = Theme.of(context).brightness == Brightness.light;
    final currentTheme = provider.mapTheme;

    final options = [
      {
        'theme': AppMapTheme.auto,
        'title': 'Auto (Theme)',
        'subtitle': 'Follows App',
        'type': 'auto',
      },
      {
        'theme': AppMapTheme.darkMatter,
        'title': 'Default Dark',
        'subtitle': 'Carto Dark',
        'type': 'dark',
      },
      {
        'theme': AppMapTheme.cartoLight,
        'title': 'Default Light',
        'subtitle': 'Carto Positron',
        'type': 'light',
      },
      {
        'theme': AppMapTheme.satellite,
        'title': 'Satellite',
        'subtitle': 'ESRI Aerial',
        'type': 'satellite',
      },
      {
        'theme': AppMapTheme.street,
        'title': 'Street',
        'subtitle': 'OpenStreetMap',
        'type': 'street',
      },
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.white.withValues(alpha: 0.95)
                  : AppTheme.deepNavy.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isLight
                    ? const Color(0xFFCBD5E1)
                    : AppTheme.electricCyan.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.12)
                      : AppTheme.electricCyan.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.electricCyan.withValues(alpha: 0.15),
                            border: Border.all(
                              color: AppTheme.electricCyan,
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.layers_rounded,
                            color: AppTheme.electricCyan,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Map Theme Styles',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isLight
                                    ? const Color(0xFF0F172A)
                                    : Colors.white,
                              ),
                            ),
                            Text(
                              'Select live tile layer overlay',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isLight
                                    ? const Color(0xFF64748B)
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isLight
                            ? const Color(0xFF64748B)
                            : AppTheme.textSecondary,
                        size: 22,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Grid of options
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: options.map((opt) {
                    final theme = opt['theme'] as AppMapTheme;
                    final title = opt['title'] as String;
                    final subtitle = opt['subtitle'] as String;
                    final type = opt['type'] as String;
                    final isSelected = currentTheme == theme;

                    return GestureDetector(
                      onTap: () {
                        provider.setMapTheme(theme);
                        Navigator.of(context).pop();
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.electricCyan
                                    : (isLight
                                        ? const Color(0xFFCBD5E1)
                                        : Colors.white.withValues(alpha: 0.15)),
                                width: isSelected ? 2.5 : 1.2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.electricCyan
                                            .withValues(alpha: 0.55),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 6,
                                      ),
                                    ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: _buildMockPreview(type, isLight),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.electricCyan,
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.check,
                                            size: 13,
                                            color: AppTheme.deepNavy,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? (isLight ? const Color(0xFF0284C7) : AppTheme.electricCyan)
                                  : (isLight ? const Color(0xFF1E293B) : Colors.white),
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: isLight
                                  ? const Color(0xFF94A3B8)
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Preference automatically saved to device memory',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isLight ? const Color(0xFF94A3B8) : AppTheme.textMuted,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMockPreview(String type, bool isLight) {
    switch (type) {
      case 'dark':
        // Carto Dark Matter mock preview
        return Container(
          color: const Color(0xFF111827),
          child: CustomPaint(
            painter: _MapGridPainter(
              roadColor: const Color(0xFF00F0FF).withValues(alpha: 0.75),
              blockColor: const Color(0xFF1F2937),
              accentColor: const Color(0xFF00E5FF),
            ),
          ),
        );
      case 'light':
        // Carto Positron Light mock preview
        return Container(
          color: const Color(0xFFF1F5F9),
          child: CustomPaint(
            painter: _MapGridPainter(
              roadColor: const Color(0xFF94A3B8),
              blockColor: const Color(0xFFE2E8F0),
              accentColor: const Color(0xFF0284C7),
            ),
          ),
        );
      case 'satellite':
        // ESRI Satellite mock preview
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E3A2F),
                Color(0xFF2D4A3E),
                Color(0xFF4A4E39),
              ],
            ),
          ),
          child: CustomPaint(
            painter: _MapGridPainter(
              roadColor: const Color(0xFFFFD54F).withValues(alpha: 0.8),
              blockColor: const Color(0xFF142920),
              accentColor: const Color(0xFF81C784),
            ),
          ),
        );
      case 'street':
        // OpenStreetMap street mock preview
        return Container(
          color: const Color(0xFFFFFBEB),
          child: CustomPaint(
            painter: _MapGridPainter(
              roadColor: const Color(0xFFF59E0B),
              blockColor: const Color(0xFFE0E7FF),
              accentColor: const Color(0xFF10B981),
            ),
          ),
        );
      case 'auto':
      default:
        // Half light, half dark
        return Row(
          children: [
            Expanded(
              child: Container(
                color: const Color(0xFFF1F5F9),
                child: const Center(
                  child: Icon(Icons.wb_sunny_rounded, size: 20, color: Color(0xFFF59E0B)),
                ),
              ),
            ),
            Container(width: 1.5, color: AppTheme.electricCyan),
            Expanded(
              child: Container(
                color: const Color(0xFF0F172A),
                child: const Center(
                  child: Icon(Icons.nightlight_round, size: 18, color: AppTheme.electricCyan),
                ),
              ),
            ),
          ],
        );
    }
  }
}

class _MapGridPainter extends CustomPainter {
  final Color roadColor;
  final Color blockColor;
  final Color accentColor;

  _MapGridPainter({
    required this.roadColor,
    required this.blockColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final blockPaint = Paint()
      ..color = blockColor
      ..style = PaintingStyle.fill;

    // Draw small city blocks
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 8, size.width * 0.38, size.height * 0.35),
        const Radius.circular(3),
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.55, 8, size.width * 0.36, size.height * 0.38),
        const Radius.circular(3),
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, size.height * 0.55, size.width * 0.42, size.height * 0.35),
        const Radius.circular(3),
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.58, size.height * 0.55, size.width * 0.34, size.height * 0.35),
        const Radius.circular(3),
      ),
      blockPaint,
    );

    // Draw roads
    final roadPaint = Paint()
      ..color = roadColor
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke;

    // Vertical road
    canvas.drawLine(
      Offset(size.width * 0.49, 0),
      Offset(size.width * 0.49, size.height),
      roadPaint,
    );
    // Horizontal road
    canvas.drawLine(
      Offset(0, size.height * 0.48),
      Offset(size.width, size.height * 0.48),
      roadPaint,
    );

    // Center node dot
    final dotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.49, size.height * 0.48), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
