import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CyberAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? leading;
  final String? titleText;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBack;

  const CyberAppBar({
    super.key,
    this.leading,
    this.titleText,
    this.titleWidget,
    this.actions,
    this.showBackButton = true,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(68.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 18,
        right: 18,
        bottom: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Leading button
          leading ??
              (showBackButton
                  ? CyberCircleIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      iconSize: 18,
                      onTap: onBack ?? () => Navigator.of(context).maybePop(),
                    )
                  : const SizedBox(width: 44)),

          // Title
          titleWidget ??
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, AppTheme.electricCyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  titleText ?? 'NodeLink',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: actions ?? [const SizedBox(width: 44)],
          ),
        ],
      ),
    );
  }
}

class CyberCircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final Color? borderColor;

  const CyberCircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 46.0,
    this.iconSize = 20.0,
    this.iconColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.spaceIndigo.withValues(alpha: 0.5),
              border: Border.all(
                color: borderColor ?? AppTheme.electricCyan.withValues(alpha: 0.25),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor ?? AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
