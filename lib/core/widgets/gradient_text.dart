import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient,
    this.overflow,
    this.maxLines,
  });

  final String text;
  final TextStyle? style;
  final Gradient? gradient;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => (gradient ?? AppColors.primaryGradient)
          .createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(
        text,
        style: style ?? AppTypography.headlineLarge,
        overflow: overflow,
        maxLines: maxLines,
      ),
    );
  }
}
