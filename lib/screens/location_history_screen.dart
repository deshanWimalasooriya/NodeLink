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

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: const CyberAppBar(
        titleText: 'Location Logs',
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location History',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Chronological node breadcrumbs with motion tags.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),

            Expanded(
              child: history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.timeline_rounded, size: 48, color: AppTheme.textMuted),
                          SizedBox(height: 12),
                          Text(
                            'No breadcrumb records yet.\nLogs appear after polling cycles.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: history.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = history[index];
                        final isMoving = item.motionState != 'STILL';

                        return CyberCard(
                          borderRadius: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          borderColor: (isMoving ? AppTheme.electricCyan : AppTheme.neonGreen)
                              .withValues(alpha: 0.25),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (isMoving ? AppTheme.electricCyan : AppTheme.neonGreen)
                                      .withValues(alpha: 0.15),
                                ),
                                child: Icon(
                                  isMoving
                                      ? Icons.directions_walk_rounded
                                      : Icons.location_pin,
                                  color: isMoving ? AppTheme.electricCyan : AppTheme.neonGreen,
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
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            color: isMoving
                                                ? AppTheme.electricCyan.withValues(alpha: 0.15)
                                                : AppTheme.neonGreen.withValues(alpha: 0.15),
                                            border: Border.all(
                                              color: isMoving
                                                  ? AppTheme.electricCyan
                                                  : AppTheme.neonGreen,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            item.motionState,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: isMoving
                                                  ? AppTheme.electricCyan
                                                  : AppTheme.neonGreen,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.latitude.toStringAsFixed(5)}, ${item.longitude.toStringAsFixed(5)} • Battery: ${item.batteryLevel}%',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
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
