import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/cyber_button.dart';
import '../core/widgets/cyber_avatar.dart';
import '../providers/node_link_provider.dart';
import 'onboarding_welcome_screen.dart';
import 'connection_hub_screen.dart';
import 'settings_screen.dart';
import 'user_profile_screen.dart';
import 'battery_management_screen.dart';
import 'location_history_screen.dart';

class SideMenuDrawer extends StatelessWidget {
  const SideMenuDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NodeLinkProvider>();
    final user = provider.currentUser;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final width = MediaQuery.of(context).size.width * 0.78;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: width,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isLight
                  ? theme.colorScheme.surface.withValues(alpha: 0.96)
                  : AppTheme.deepNavy.withValues(alpha: 0.88),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              border: Border.all(
                color: isLight
                    ? AppTheme.lightBorder
                    : AppTheme.electricCyan.withValues(alpha: 0.22),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isLight
                      ? const Color(0xFF0F172A).withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // Top Profile Header (Nuwan)
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                        );
                      },
                      child: Row(
                        children: [
                          CyberAvatar.fromUser(
                            user: user,
                            size: 62,
                            showGlow: true,
                            borderWidth: 2,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name.split(' ').first,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: theme.textTheme.bodyLarge?.color ??
                                        (isLight ? AppTheme.lightTextPrimary : Colors.white),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isLight ? AppTheme.cyberTeal : AppTheme.neonGreen,
                                      width: 1.0,
                                    ),
                                    color: (isLight ? AppTheme.cyberTeal : AppTheme.neonGreen)
                                        .withValues(alpha: 0.12),
                                  ),
                                  child: Text(
                                    'Node ID: ${user.id}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isLight ? const Color(0xFF0D9488) : AppTheme.neonGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Navigation List
                    _buildNavItem(
                      context,
                      icon: Icons.location_on_outlined,
                      label: 'Live Map',
                      isActive: true,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 8),
                    _buildNavItem(
                      context,
                      icon: Icons.link_rounded,
                      label: 'Connection Hub',
                      isActive: false,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ConnectionHubScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildNavItem(
                      context,
                      icon: Icons.history_rounded,
                      label: 'Location History',
                      isActive: false,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LocationHistoryScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildNavItem(
                      context,
                      icon: Icons.battery_charging_full_rounded,
                      label: 'Battery Management',
                      isActive: false,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BatteryManagementScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildNavItem(
                      context,
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      isActive: false,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),

                    const Spacer(),

                    // Footer Logout button
                    CyberButton(
                      text: 'Log Out',
                      variant: CyberButtonVariant.dangerOutline,
                      height: 48,
                      onPressed: () async {
                        final provider = context.read<NodeLinkProvider>();
                        await provider.logout();
                        if (context.mounted) {
                          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const OnboardingWelcomeScreen()),
                            (route) => false,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        'NodeLink v1.0.2',
                        style: TextStyle(
                          fontSize: 12,
                          color: isLight ? AppTheme.lightTextMuted : AppTheme.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isActive
            ? (isLight
                ? primaryColor.withValues(alpha: 0.12)
                : AppTheme.spaceIndigo.withValues(alpha: 0.7))
            : Colors.transparent,
        border: isActive
            ? Border.all(
                color: isLight
                    ? primaryColor.withValues(alpha: 0.35)
                    : AppTheme.electricCyan.withValues(alpha: 0.4),
                width: 1.0,
              )
            : null,
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(
          icon,
          color: isActive
              ? (isLight ? const Color(0xFF0284C7) : AppTheme.electricCyan)
              : (isLight
                  ? const Color(0xFF64748B) // Readable medium-grey in light mode
                  : AppTheme.electricCyan.withValues(alpha: 0.75)),
          size: 24,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive
                ? (isLight ? const Color(0xFF0F172A) : Colors.white)
                : (isLight ? const Color(0xFF334155) : AppTheme.textPrimary),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: isLight ? const Color(0xFF94A3B8) : AppTheme.textMuted,
          size: 20,
        ),
      ),
    );
  }
}
