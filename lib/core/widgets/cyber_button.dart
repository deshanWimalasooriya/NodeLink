import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum CyberButtonVariant {
  primary, // Electric Cyan solid filled
  neon,    // Neon Green solid filled
  outline, // Cyan outline frosted
  dangerOutline, // Red outline frosted for disconnect / logout
}

class CyberButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final CyberButtonVariant variant;
  final double height;
  final double? width;
  final double borderRadius;
  final bool isLoading;

  const CyberButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.variant = CyberButtonVariant.primary,
    this.height = 54.0,
    this.width,
    this.borderRadius = 28.0,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final primaryAccent = theme.colorScheme.primary;

    Color bgColor;
    Color textColor;
    Color borderColor;
    List<BoxShadow> shadows = [];

    switch (variant) {
      case CyberButtonVariant.primary:
        bgColor = primaryAccent;
        textColor = AppTheme.deepNavy;
        borderColor = Colors.transparent;
        shadows = isLight
            ? AppTheme.lightCardShadow
            : AppTheme.cyanGlow(blur: 16, opacity: 0.45);
        break;
      case CyberButtonVariant.neon:
        bgColor = AppTheme.neonGreen;
        textColor = AppTheme.deepNavy;
        borderColor = Colors.transparent;
        shadows = isLight
            ? AppTheme.lightCardShadow
            : AppTheme.neonGlow(blur: 16, opacity: 0.45);
        break;
      case CyberButtonVariant.outline:
        bgColor = isLight
            ? primaryAccent.withValues(alpha: 0.08)
            : AppTheme.spaceIndigo.withValues(alpha: 0.35);
        textColor = isLight ? const Color(0xFF0284C7) : AppTheme.electricCyan;
        borderColor = isLight
            ? const Color(0xFF0284C7).withValues(alpha: 0.4)
            : AppTheme.electricCyan.withValues(alpha: 0.5);
        shadows = [];
        break;
      case CyberButtonVariant.dangerOutline:
        bgColor = isLight
            ? AppTheme.warningRed.withValues(alpha: 0.08)
            : AppTheme.warningRed.withValues(alpha: 0.12);
        textColor = AppTheme.warningRed;
        borderColor = AppTheme.warningRed.withValues(alpha: isLight ? 0.35 : 0.5);
        shadows = [];
        break;
    }

    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Ink(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: textColor,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: textColor, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          text,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
