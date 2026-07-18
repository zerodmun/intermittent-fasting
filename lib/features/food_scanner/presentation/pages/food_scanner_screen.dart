// Future Planned Features:
// • Take photo / Camera integration
// • Choose image from gallery
// • AI food recognition and classification
// • Calorie estimation from image analysis
// • Macronutrients tracking (proteins, fats, carbs)
// • Micronutrients tracking (vitamins, minerals)
// • Scan history log
// • Barcode scanner for packaged foods
// • Nutrition facts label scanner (OCR)
// • Daily calorie tracking and allowance integration
// • Integration with Weight Tracker
// • Integration with Body Composition

import 'package:flutter/material.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/app_button.dart';

class FoodScannerScreen extends StatelessWidget {
  const FoodScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Scanner'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              // Premium illustration card
              AppCard.elevated(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: AspectRatio(
                    aspectRatio: 1.1,
                    child: Image.asset(
                      'assets/illustrations/food_scanner_illustration.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xlg),
              Text(
                'Food Calorie Scanner',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This feature will allow you to estimate calories and nutrition from food photos.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xlg),
              // Status Card: Coming Soon
              AppCard.outlined(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: context.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.insights_rounded,
                        color: context.colorScheme.onPrimaryContainer,
                        size: AppSpacing.iconXl,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Coming Soon',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: context.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('🚧'),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'AI-powered food recognition and nutrition analysis will be available in a future update.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              // Disabled Action Button
              AppButton.primary(
                label: 'Coming Soon',
                onPressed: null, // Disabled
              ),
            ],
          ),
        ),
      ),
    );
  }
}
