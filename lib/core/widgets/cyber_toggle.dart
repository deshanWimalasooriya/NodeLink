import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CyberToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const CyberToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final activeBg = isLight ? AppTheme.electricCyan : AppTheme.neonGreen.withValues(alpha: 0.85);
    final inactiveBg = isLight ? const Color(0xFFE2E8F0) : AppTheme.spaceIndigo.withValues(alpha: 0.6);
    final activeBorder = isLight ? AppTheme.electricCyan : AppTheme.neonGreen;
    final inactiveBorder = isLight ? const Color(0xFFCBD5E1) : AppTheme.electricCyan.withValues(alpha: 0.2);

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 60,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: value ? activeBg : inactiveBg,
          border: Border.all(
            color: value ? activeBorder : inactiveBorder,
            width: 1.2,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: (isLight ? AppTheme.electricCyan : AppTheme.neonGreen).withValues(alpha: 0.45),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Text Label (ON / OFF)
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: value ? Alignment.centerLeft : Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  value ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: value ? AppTheme.deepNavy : (isLight ? AppTheme.lightTextMuted : AppTheme.textMuted),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            // Sliding thumb
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? Colors.white : (isLight ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
