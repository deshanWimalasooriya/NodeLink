import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/cyber_card.dart';
import '../core/widgets/cyber_app_bar.dart';
import '../providers/node_link_provider.dart';

class LocationHistoryScreen extends StatelessWidget {
  const LocationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NodeLinkProvider>();
    final history = provider.locationHistory;
    final timeFormat = DateFormat('hh:mm:ss a');
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final textColor = theme.textTheme.bodyLarge?.color ??
        (isLight ? AppTheme.lightTextPrimary : Colors.white);
    final secondaryTextColor =
        isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const CyberAppBar(
        titleText: 'Location Logs',
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location History',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Chronological node breadcrumbs with motion tags.',
              style: TextStyle(color: secondaryTextColor, fontSize: 13),
            ),
            const SizedBox(height: 18),

            Expanded(
              child: history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timeline_rounded,
                            size: 48,
                            color: isLight ? AppTheme.lightTextMuted : AppTheme.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No breadcrumb records yet.\nLogs appear after polling cycles.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isLight ? AppTheme.lightTextMuted : AppTheme.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: history.length,
                      separatorBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(left: 36.0),
                        child: SizedBox(
                          height: 14,
                          child: VerticalDivider(
                            color: theme.dividerColor,
                            thickness: 2.0,
                            width: 2.0,
                          ),
                        ),
                      ),
                      itemBuilder: (context, index) {
                        final item = history[index];
                        final isMoving = item.motionState != 'STILL';
                        final badgeColor = isMoving
                            ? (isLight ? const Color(0xFF0284C7) : AppTheme.electricCyan)
                            : (isLight ? const Color(0xFF059669) : AppTheme.neonGreen);

                        return CyberCard(
                          backgroundColor: theme.cardColor,
                          borderRadius: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          borderColor: isLight
                              ? AppTheme.lightCardBorder
                              : badgeColor.withValues(alpha: 0.25),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: badgeColor.withValues(alpha: 0.15),
                                ),
                                child: Icon(
                                  isMoving
                                      ? Icons.directions_walk_rounded
                                      : Icons.location_pin,
                                  color: badgeColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          timeFormat.format(item.timestamp),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            color: badgeColor.withValues(alpha: 0.12),
                                            border: Border.all(
                                              color: badgeColor,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            item.motionState,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: badgeColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.latitude.toStringAsFixed(5)}, ${item.longitude.toStringAsFixed(5)} • Battery: ${item.batteryLevel}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
