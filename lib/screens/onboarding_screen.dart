import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/cyber_card.dart';
import '../core/widgets/cyber_button.dart';
import '../services/permission_service.dart';
import '../providers/node_link_provider.dart';
import 'home_screen.dart';
import 'create_account_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _locationGranted = false;
  bool _backgroundGranted = false;
  bool _activityGranted = false;
  bool _notificationGranted = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final status = await PermissionsService.checkAllPermissions();
    if (mounted) {
      setState(() {
        _locationGranted = status['location'] ?? false;
        _backgroundGranted = status['background_location'] ?? false;
        _activityGranted = status['activity_recognition'] ?? false;
        _notificationGranted = status['notification'] ?? false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    await PermissionsService.requestAll();
    await _checkStatus();
    if (mounted) {
      final provider = context.read<NodeLinkProvider>();
      if (provider.hasAccount) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Cyber background ambient glow
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.electricCyan.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.neonGreen.withValues(alpha: 0.12),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // App Logo & Brand Header
                  Hero(
                    tag: 'nodelink_logo',
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: AppTheme.cyanGlow(blur: 24, opacity: 0.5),
                        border: Border.all(color: AppTheme.electricCyan, width: 2),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo/nodelink_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.share_location_rounded,
                            size: 48,
                            color: AppTheme.electricCyan,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.white, AppTheme.electricCyan],
                    ).createShader(bounds),
                    child: const Text(
                      'NodeLink',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Battery-Efficient Real-Time Location Mesh',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Permission Cards
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildPermissionCard(
                          icon: Icons.location_on_rounded,
                          title: 'GPS Background Access',
                          subtitle: 'Allows continuous sync when screen is off ("Always Allow")',
                          isGranted: _locationGranted || _backgroundGranted,
                          onTap: () async {
                            await PermissionsService.requestLocationPermission();
                            await PermissionsService.requestBackgroundLocation();
                            await _checkStatus();
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildPermissionCard(
                          icon: Icons.directions_walk_rounded,
                          title: 'Physical Activity Sensor',
                          subtitle: 'Detects STILL vs MOVING to throttle GPS polling & save 80% battery',
                          isGranted: _activityGranted,
                          onTap: () async {
                            await PermissionsService.requestActivityRecognition();
                            await _checkStatus();
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildPermissionCard(
                          icon: Icons.notifications_active_rounded,
                          title: 'Persistent Foreground Service',
                          subtitle: 'Keeps node sync alive with status notification',
                          isGranted: _notificationGranted,
                          onTap: () async {
                            await PermissionsService.requestNotificationPermission();
                            await _checkStatus();
                          },
                        ),
                      ],
                    ),
                  ),

                  // Continue Action Button
                  CyberButton(
                    text: 'INITIALIZE NODELINK',
                    icon: Icons.bolt_rounded,
                    onPressed: _requestPermissions,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return CyberCard(
      padding: const EdgeInsets.all(16.0),
      borderRadius: 20.0,
      borderColor: isGranted
          ? AppTheme.neonGreen.withValues(alpha: 0.5)
          : AppTheme.electricCyan.withValues(alpha: 0.2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isGranted ? AppTheme.neonGreen : AppTheme.electricCyan)
                  .withValues(alpha: 0.15),
              border: Border.all(
                color: isGranted ? AppTheme.neonGreen : AppTheme.electricCyan,
                width: 1.2,
              ),
            ),
            child: Icon(
              icon,
              size: 24,
              color: isGranted ? AppTheme.neonGreen : AppTheme.electricCyan,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isGranted
                    ? AppTheme.neonGreen.withValues(alpha: 0.2)
                    : AppTheme.electricCyan.withValues(alpha: 0.2),
                border: Border.all(
                  color: isGranted ? AppTheme.neonGreen : AppTheme.electricCyan,
                  width: 1.0,
                ),
              ),
              child: Text(
                isGranted ? 'READY' : 'GRANT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isGranted ? AppTheme.neonGreen : AppTheme.electricCyan,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
