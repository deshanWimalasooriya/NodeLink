import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/cyber_card.dart';
import '../core/widgets/cyber_button.dart';
import '../core/widgets/cyber_app_bar.dart';
import '../core/widgets/cyber_toggle.dart';
import '../models/tracking_settings.dart';
import '../providers/node_link_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TrackingSettings _localSettings;

  @override
  void initState() {
    super.initState();
    _localSettings = context.read<NodeLinkProvider>().settings;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NodeLinkProvider>();

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: CyberAppBar(
        titleText: 'NodeLink',
        actions: [
          CyberCircleIconButton(
            icon: Icons.help_outline_rounded,
            iconSize: 20,
            iconColor: AppTheme.textSecondary,
            onTap: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 18),

            // Card 1: Battery & Polling Options
            CyberCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.battery_charging_full_rounded, color: AppTheme.neonGreen, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Battery & Polling Options',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Smart Tracking Intervals',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.electricCyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Active Mode (While Moving)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Active Mode (While Moving)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _buildChipGroup(
                        options: [
                          {'label': '30 Secs', 'value': 30},
                          {'label': '1 Min', 'value': 60},
                          {'label': '5 Mins', 'value': 300},
                        ],
                        selectedValue: _localSettings.activeIntervalSec,
                        onSelected: (val) {
                          setState(() {
                            _localSettings = _localSettings.copyWith(activeIntervalSec: val);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Sleep Mode (When Still)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Sleep Mode (When Still)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _buildChipGroup(
                        options: [
                          {'label': '5 Mins', 'value': 300},
                          {'label': '10 Mins', 'value': 600},
                          {'label': '20 Mins', 'value': 1200},
                        ],
                        selectedValue: _localSettings.sleepIntervalSec,
                        onSelected: (val) {
                          setState(() {
                            _localSettings = _localSettings.copyWith(sleepIntervalSec: val);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Low Battery Saver
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Low Battery Saver',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Reduce frequency under 15%',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.electricCyan,
                            ),
                          ),
                        ],
                      ),
                      CyberToggle(
                        value: _localSettings.lowBatterySaver,
                        onChanged: (val) {
                          setState(() {
                            _localSettings = _localSettings.copyWith(lowBatterySaver: val);
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Card 2: Notifications
            CyberCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.notifications_active_rounded, color: AppTheme.electricCyan, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildSwitchRow(
                    title: 'Node Link Request',
                    value: _localSettings.nodeLinkRequestAlerts,
                    onChanged: (val) => setState(() {
                      _localSettings = _localSettings.copyWith(nodeLinkRequestAlerts: val);
                    }),
                  ),
                  const SizedBox(height: 12),
                  _buildSwitchRow(
                    title: 'Live Updates Alerts',
                    value: _localSettings.liveUpdatesAlerts,
                    onChanged: (val) => setState(() {
                      _localSettings = _localSettings.copyWith(liveUpdatesAlerts: val);
                    }),
                  ),
                  const SizedBox(height: 12),
                  _buildSwitchRow(
                    title: 'Service Running Notification',
                    subtitle: 'Keep Background Service Active',
                    value: _localSettings.serviceRunningNotification,
                    onChanged: (val) => setState(() {
                      _localSettings = _localSettings.copyWith(serviceRunningNotification: val);
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Card 3: Map Preferences
            CyberCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.map_rounded, color: AppTheme.cyberTeal, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Map Preferences',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Map Display Style',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'Cyber-Dark Mode',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.electricCyan,
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: AppTheme.electricCyan, size: 18),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildSwitchRow(
                    title: 'Profile Pics on Pins',
                    value: _localSettings.profilePicsOnPins,
                    onChanged: (val) => setState(() {
                      _localSettings = _localSettings.copyWith(profilePicsOnPins: val);
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Card 4: Privacy & Security
            CyberCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.security_rounded, color: AppTheme.cyberBlue, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Privacy & Security',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildSwitchRow(
                    title: 'Visible to Connection Only',
                    value: _localSettings.visibleToConnectionOnly,
                    onChanged: (val) => setState(() {
                      _localSettings = _localSettings.copyWith(visibleToConnectionOnly: val);
                    }),
                  ),
                  const SizedBox(height: 12),
                  _buildSwitchRow(
                    title: 'Biometric Lock',
                    value: _localSettings.biometricLock,
                    onChanged: (val) => setState(() {
                      _localSettings = _localSettings.copyWith(biometricLock: val);
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // SAVE SETTINGS button
            CyberButton(
              text: 'SAVE SETTINGS',
              onPressed: () async {
                final scaffold = ScaffoldMessenger.of(context);
                final nav = Navigator.of(context);
                await provider.updateSettings(_localSettings);
                if (mounted) {
                  scaffold.showSnackBar(
                    const SnackBar(
                      content: Text('Settings saved successfully!'),
                      backgroundColor: AppTheme.neonGreen,
                    ),
                  );
                  nav.pop();
                }
              },
            ),

            const SizedBox(height: 16),
            const Center(
              child: Text(
                'NodeLink App Version 1.0.2',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.electricCyan,
                  ),
                ),
              ],
            ],
          ),
        ),
        CyberToggle(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildChipGroup({
    required List<Map<String, dynamic>> options,
    required int selectedValue,
    required ValueChanged<int> onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.deepNavy.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.electricCyan.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = opt['value'] == selectedValue;
          return GestureDetector(
            onTap: () => onSelected(opt['value'] as int),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: isSelected ? AppTheme.electricCyan : Colors.transparent,
                boxShadow: isSelected ? AppTheme.cyanGlow(blur: 8, opacity: 0.3) : null,
              ),
              child: Text(
                opt['label'] as String,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? AppTheme.deepNavy : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.deepNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppTheme.electricCyan, width: 1.2),
        ),
        title: const Text('NodeLink Architecture', style: TextStyle(color: Colors.white)),
        content: const Text(
          'NodeLink utilizes motion sensor acceleration heuristics to detect STILL vs ACTIVE states. '
          'STILL updates location every 10 mins, saving 80% battery.\n\n'
          'Low battery throttling throttles polling to 20 minutes when battery is below 15%.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GOT IT', style: TextStyle(color: AppTheme.electricCyan)),
          ),
        ],
      ),
    );
  }
}
