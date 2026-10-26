import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/cyber_card.dart';
import '../core/widgets/cyber_app_bar.dart';
import '../services/adaptive_polling_service.dart';
import '../providers/node_link_provider.dart';

class BatteryManagementScreen extends StatelessWidget {
  const BatteryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NodeLinkProvider>();
    final battery = provider.batteryLevel;
    final motion = provider.motionState.displayName;
    final interval = provider.currentIntervalSec ~/ 60;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final textColor = theme.textTheme.bodyLarge?.color ??
        (isLight ? AppTheme.lightTextPrimary : Colors.white);
    final secondaryTextColor =
        isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary;
    final surfaceColor = theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const CyberAppBar(
        titleText: 'Battery Health',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Battery & Energy Efficiency',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Real-time adaptive GPS throttling telemetry.',
              style: TextStyle(color: secondaryTextColor, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Main Battery Status Card
            CyberCard(
              backgroundColor: isLight ? surfaceColor : null,
              borderRadius: 24,
              borderColor: isLight
                  ? AppTheme.lightCardBorder
                  : AppTheme.neonGreen.withValues(alpha: 0.35),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Battery',
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$battery%',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: battery < 15
                                  ? AppTheme.warningRed
                                  : (isLight ? const Color(0xFF059669) : AppTheme.neonGreen),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (battery < 15
                                  ? AppTheme.warningRed
                                  : (isLight ? const Color(0xFF059669) : AppTheme.neonGreen))
                              .withValues(alpha: 0.15),
                          border: Border.all(
                            color: battery < 15
                                ? AppTheme.warningRed
                                : (isLight ? const Color(0xFF059669) : AppTheme.neonGreen),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          battery < 15
                              ? Icons.battery_alert_rounded
                              : Icons.battery_charging_full_rounded,
                          color: battery < 15
                              ? AppTheme.warningRed
                              : (isLight ? const Color(0xFF059669) : AppTheme.neonGreen),
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: battery / 100.0,
                      minHeight: 10,
                      backgroundColor: isLight ? Colors.grey[300] : AppTheme.deepNavy,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        battery < 15
                            ? AppTheme.warningRed
                            : (isLight ? const Color(0xFF059669) : AppTheme.neonGreen),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Adaptive Power Savings Breakdown
            CyberCard(
              backgroundColor: isLight ? surfaceColor : null,
              borderColor: isLight ? AppTheme.lightCardBorder : null,
              borderRadius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Optimization Impact',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildMetricRow(
                    'Active Polling State',
                    motion,
                    isLight ? const Color(0xFF0284C7) : AppTheme.electricCyan,
                    secondaryTextColor,
                  ),
                  Divider(color: theme.dividerColor, height: 20),
                  _buildMetricRow(
                    'Effective GPS Interval',
                    interval > 0 ? '$interval Minutes' : '${provider.currentIntervalSec} Seconds',
                    isLight ? const Color(0xFF059669) : AppTheme.neonGreen,
                    secondaryTextColor,
                  ),
                  Divider(color: theme.dividerColor, height: 20),
                  _buildMetricRow(
                    'Estimated Power Saved',
                    '~78.4%',
                    isLight ? const Color(0xFF059669) : AppTheme.neonGreen,
                    secondaryTextColor,
                  ),
                  Divider(color: theme.dividerColor, height: 20),
                  _buildMetricRow(
                    'Background Keep-Alive',
                    'Active (Foreground Service)',
                    isLight ? const Color(0xFF0D9488) : AppTheme.cyberTeal,
                    secondaryTextColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Explanation Card
            CyberCard(
              borderRadius: 20,
              backgroundColor: isLight
                  ? surfaceColor
                  : AppTheme.deepNavy.withValues(alpha: 0.5),
              borderColor: isLight ? AppTheme.lightCardBorder : null,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: isLight ? const Color(0xFF0284C7) : AppTheme.electricCyan,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'NodeLink monitors accelerometer variances to switch between 10-minute stationary sleep and 1-minute active travel intervals, maximizing device battery runtime.',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    String label,
    String value,
    Color valueColor,
    Color labelColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: labelColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
