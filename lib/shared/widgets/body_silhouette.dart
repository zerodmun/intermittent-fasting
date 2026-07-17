import 'package:flutter/material.dart';
import '../../core/constants/app_spacing.dart';

class BodySilhouette extends StatelessWidget {
  final double bodyFatPercent;
  final double leanMassPercent;
  final double fatMassPercent;
  final String gender; // 'male' or 'female'

  const BodySilhouette({
    required this.bodyFatPercent,
    required this.leanMassPercent,
    required this.fatMassPercent,
    required this.gender,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 0.6,
            child: CustomPaint(
              painter: _BodySilhouettePainter(
                bodyFatPercent: bodyFatPercent,
                gender: gender,
                primaryColor: colorScheme.primary,
                secondaryColor: colorScheme.secondary,
                outlineColor: colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMetric(context, 'Lean', '$leanMassPercent%', colorScheme.primary),
            _buildMetric(context, 'Fat', '$fatMassPercent%', colorScheme.secondary),
          ],
        ),
      ],
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _BodySilhouettePainter extends CustomPainter {
  final double bodyFatPercent;
  final String gender;
  final Color primaryColor;
  final Color secondaryColor;
  final Color outlineColor;

  _BodySilhouettePainter({
    required this.bodyFatPercent,
    required this.gender,
    required this.primaryColor,
    required this.secondaryColor,
    required this.outlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintOutline = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final paintFill = Paint()
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Build human silhouette path
    if (gender.toLowerCase() == 'female') {
      // Head
      path.addOval(Rect.fromCircle(center: Offset(w / 2, h * 0.1), radius: w * 0.08));
      
      // Neck
      path.moveTo(w * 0.46, h * 0.16);
      path.lineTo(w * 0.46, h * 0.2);
      path.lineTo(w * 0.54, h * 0.2);
      path.lineTo(w * 0.54, h * 0.16);

      // Shoulders & Torso
      path.moveTo(w * 0.46, h * 0.2);
      path.quadraticBezierTo(w * 0.3, h * 0.22, w * 0.26, h * 0.28); // Left shoulder
      path.lineTo(w * 0.32, h * 0.45); // Left arm inner
      path.quadraticBezierTo(w * 0.38, h * 0.52, w * 0.38, h * 0.56); // Waist left (hourglass curve)
      path.quadraticBezierTo(w * 0.3, h * 0.65, w * 0.28, h * 0.72); // Hips left
      path.lineTo(w * 0.36, h * 0.95); // Left leg outer
      path.lineTo(w * 0.46, h * 0.95); // Left foot
      path.lineTo(w * 0.48, h * 0.65); // Left leg inner crotch
      path.lineTo(w * 0.52, h * 0.65); // Right leg inner crotch
      path.lineTo(w * 0.54, h * 0.95); // Right foot inner
      path.lineTo(w * 0.64, h * 0.95); // Right leg outer
      path.quadraticBezierTo(w * 0.7, h * 0.65, w * 0.62, h * 0.56); // Hips right
      path.quadraticBezierTo(w * 0.62, h * 0.52, w * 0.68, h * 0.45); // Waist right
      path.lineTo(w * 0.74, h * 0.28); // Right arm inner
      path.quadraticBezierTo(w * 0.7, h * 0.22, w * 0.54, h * 0.2); // Right shoulder
    } else {
      // Male Silhouette (V-Shape / broader shoulders, narrower hips)
      // Head
      path.addOval(Rect.fromCircle(center: Offset(w / 2, h * 0.1), radius: w * 0.09));

      // Neck
      path.moveTo(w * 0.45, h * 0.17);
      path.lineTo(w * 0.45, h * 0.21);
      path.lineTo(w * 0.55, h * 0.21);
      path.lineTo(w * 0.55, h * 0.17);

      // Shoulders & Torso
      path.moveTo(w * 0.45, h * 0.21);
      path.quadraticBezierTo(w * 0.24, h * 0.23, w * 0.2, h * 0.28); // Left shoulder (broader)
      path.lineTo(w * 0.28, h * 0.46); // Left arm
      path.lineTo(w * 0.34, h * 0.56); // Waist left (straight / slight V)
      path.quadraticBezierTo(w * 0.33, h * 0.63, w * 0.32, h * 0.7); // Hips left (narrower)
      path.lineTo(w * 0.38, h * 0.95); // Left leg outer
      path.lineTo(w * 0.47, h * 0.95); // Left foot
      path.lineTo(w * 0.49, h * 0.64); // Crotch left
      path.lineTo(w * 0.51, h * 0.64); // Crotch right
      path.lineTo(w * 0.53, h * 0.95); // Right foot inner
      path.lineTo(w * 0.62, h * 0.95); // Right leg outer
      path.quadraticBezierTo(w * 0.67, h * 0.63, w * 0.66, h * 0.56); // Hips right
      path.lineTo(w * 0.72, h * 0.46); // Waist right
      path.lineTo(w * 0.8, h * 0.28); // Right arm
      path.quadraticBezierTo(w * 0.76, h * 0.23, w * 0.55, h * 0.21); // Right shoulder
    }

    // Draw background silhouette outline
    canvas.drawPath(path, paintOutline);

    // Dynamic filling representing fat vs lean mass.
    // We will fill the silhouette from bottom to top.
    // The bottom part (legs, hips, etc) will be filled with primary (lean).
    // The top part or fat ratio level can represent the composition.
    // To make it look extremely premium, let's split the filling vertically or horizontally.
    // A horizontal split: fill from bottom to a height relative to (100 - bodyFatPercent).
    canvas.save();
    canvas.clipPath(path);

    // Fill representing Fat Mass (Secondary) at the waist/center region or as a bottom-to-top split
    final fillHeight = h * (bodyFatPercent / 100);
    
    // Lean mass fill (bottom portion)
    paintFill.color = primaryColor.withValues(alpha: 0.85);
    canvas.drawRect(Rect.fromLTRB(0, fillHeight, w, h), paintFill);

    // Fat mass fill (top portion)
    paintFill.color = secondaryColor.withValues(alpha: 0.85);
    canvas.drawRect(Rect.fromLTRB(0, 0, w, fillHeight), paintFill);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BodySilhouettePainter oldDelegate) {
    return oldDelegate.bodyFatPercent != bodyFatPercent ||
        oldDelegate.gender != gender ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.outlineColor != outlineColor;
  }
}
