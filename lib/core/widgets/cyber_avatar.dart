import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../../models/node_user.dart';

class CyberAvatar extends StatelessWidget {
  final String? profilePicUrl;
  final String? avatarAsset;
  final String name;
  final double size;
  final Color? borderColor;
  final double borderWidth;
  final bool showGlow;
  final bool showStatusBadge;
  final bool isOnline;
  final Widget? badgeWidget;
  final VoidCallback? onTap;

  const CyberAvatar({
    super.key,
    this.profilePicUrl,
    this.avatarAsset,
    this.name = '',
    this.size = 48.0,
    this.borderColor,
    this.borderWidth = 2.0,
    this.showGlow = false,
    this.showStatusBadge = false,
    this.isOnline = false,
    this.badgeWidget,
    this.onTap,
  });

  factory CyberAvatar.fromUser({
    Key? key,
    required NodeUser user,
    double size = 48.0,
    Color? borderColor,
    double borderWidth = 2.0,
    bool showGlow = false,
    bool showStatusBadge = false,
    VoidCallback? onTap,
  }) {
    return CyberAvatar(
      key: key,
      profilePicUrl: user.profilePicUrl,
      avatarAsset: user.avatarPath,
      name: user.name,
      size: size,
      borderColor: borderColor,
      borderWidth: borderWidth,
      showGlow: showGlow,
      showStatusBadge: showStatusBadge,
      isOnline: user.status == 'Online' || user.status == 'Active',
      onTap: onTap,
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '';
    return Container(
      width: size,
      height: size,
      color: isLight ? const Color(0xFFE2E8F0) : AppTheme.spaceIndigo,
      alignment: Alignment.center,
      child: initial.isNotEmpty
          ? Text(
              initial,
              style: TextStyle(
                fontSize: size * 0.45,
                fontWeight: FontWeight.w900,
                color: isLight ? const Color(0xFF0284C7) : AppTheme.electricCyan,
                letterSpacing: 0.5,
              ),
            )
          : Icon(
              Icons.person_rounded,
              size: size * 0.55,
              color: isLight ? const Color(0xFF0284C7) : AppTheme.electricCyan,
            ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    // 1. Prioritize profilePicUrl from Firebase Storage / Realtime Database
    if (profilePicUrl != null && profilePicUrl!.trim().isNotEmpty) {
      final cleanUrl = profilePicUrl!.trim();
      if (cleanUrl.startsWith('data:image')) {
        try {
          final base64String = cleanUrl.split(',').last;
          final bytes = base64Decode(base64String);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
          );
        } catch (_) {
          return _buildPlaceholder(context);
        }
      }

      final isLight = Theme.of(context).brightness == Brightness.light;
      return CachedNetworkImage(
        imageUrl: cleanUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: isLight ? const Color(0xFFE2E8F0) : AppTheme.spaceIndigo,
          child: Center(
            child: SizedBox(
              width: size * 0.35,
              height: size * 0.35,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: isLight ? const Color(0xFF0284C7) : AppTheme.electricCyan,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholder(context),
      );
    }

    // 2. Check avatarAsset if available and valid
    if (avatarAsset != null &&
        avatarAsset!.trim().isNotEmpty &&
        !avatarAsset!.startsWith('http')) {
      return Image.asset(
        avatarAsset!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
      );
    }

    // 3. Fallback to default placeholder avatar (Initial / User Icon)
    return _buildPlaceholder(context);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final effectiveBorderColor = borderColor ??
        (isOnline
            ? (isLight ? const Color(0xFF059669) : AppTheme.neonGreen)
            : (isLight ? const Color(0xFF0284C7) : AppTheme.electricCyan));

    Widget avatarCore = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
        boxShadow: showGlow
            ? (isOnline
                ? (isLight
                    ? AppTheme.lightCardShadow
                    : AppTheme.neonGlow(blur: size * 0.25, opacity: 0.5))
                : (isLight
                    ? AppTheme.lightCardShadow
                    : AppTheme.cyanGlow(blur: size * 0.25, opacity: 0.45)))
            : null,
      ),
      child: ClipOval(
        child: _buildImageContent(context),
      ),
    );

    if (onTap != null) {
      avatarCore = GestureDetector(
        onTap: onTap,
        child: avatarCore,
      );
    }

    if (!showStatusBadge && badgeWidget == null) {
      return avatarCore;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarCore,
        if (badgeWidget != null)
          badgeWidget!
        else if (showStatusBadge)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline
                    ? (isLight ? const Color(0xFF059669) : AppTheme.neonGreen)
                    : (isLight ? const Color(0xFF0284C7) : AppTheme.electricCyan),
                border: Border.all(
                  color: isLight ? Colors.white : AppTheme.deepNavy,
                  width: size * 0.05,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
