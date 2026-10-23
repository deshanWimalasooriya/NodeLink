import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RadarPulseIndicator extends StatefulWidget {
  final double size;
  final Widget child;
  final Color primaryColor;
  final Color secondaryColor;
  final bool animate;

  const RadarPulseIndicator({
    super.key,
    this.size = 100.0,
    required this.child,
    this.primaryColor = AppTheme.electricCyan,
    this.secondaryColor = AppTheme.neonGreen,
    this.animate = true,
  });

  @override
  State<RadarPulseIndicator> createState() => _RadarPulseIndicatorState();
}

class _RadarPulseIndicatorState extends State<RadarPulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant RadarPulseIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Ripple 1
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final val = (_controller.value + 0.0) % 1.0;
              final opacity = (1.0 - val).clamp(0.0, 1.0);
              return Container(
                width: widget.size * (0.4 + 0.6 * val),
                height: widget.size * (0.4 + 0.6 * val),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.primaryColor.withValues(alpha: opacity * 0.7),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.primaryColor.withValues(alpha: opacity * 0.25),
                      blurRadius: 10 * val,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              );
            },
          ),

          // Outer Ripple 2 (staggered)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final val = (_controller.value + 0.5) % 1.0;
              final opacity = (1.0 - val).clamp(0.0, 1.0);
              return Container(
                width: widget.size * (0.4 + 0.6 * val),
                height: widget.size * (0.4 + 0.6 * val),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.secondaryColor.withValues(alpha: opacity * 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.secondaryColor.withValues(alpha: opacity * 0.2),
                      blurRadius: 8 * val,
                    ),
                  ],
                ),
              );
            },
          ),

          // Core Child (e.g. Avatar or Location Dot)
          widget.child,
        ],
      ),
    );
  }
}
