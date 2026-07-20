import 'package:flutter/material.dart';
import '../../core/constants/app_spacing.dart';
import 'app_card.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String title;
  final Widget? infoButton;
  final Color? iconColor;
  final VoidCallback? onTap;

  const StatCard({
    required this.icon,
    required this.value,
    required this.title,
    this.infoButton,
    this.iconColor,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveColor = iconColor ?? theme.colorScheme.primary;

    return AppCard.elevated(
      onTap: onTap,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Header Row (Fixed height)
          SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    color: effectiveColor,
                    size: AppSpacing.iconMd,
                  ),
                ),
                if (infoButton != null) infoButton!,
              ],
            ),
          ),
          const SizedBox(height: 20.0), // Spacing: Header -> Value: 20-24dp
          // Main Value
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(height: 8.0), // Spacing: Value -> Title: 6-8dp
          // Title
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.left,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
