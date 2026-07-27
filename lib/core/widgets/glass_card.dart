import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(borderRadius ?? AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: AppColors.pinkGlow(intensity: 8),
      ),
      child: child,
    );
  }
}
