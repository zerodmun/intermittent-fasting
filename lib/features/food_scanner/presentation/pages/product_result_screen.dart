import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../providers/food_logs_provider.dart';
import '../../services/food_search_service.dart';

class ProductResultScreen extends ConsumerWidget {
  final FoodProduct product;

  const ProductResultScreen({required this.product, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Scanned Product',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                product.name,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (product.brand.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  product.brand,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (product.imageUrl != null && product.imageUrl!.isNotEmpty) ...[
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: Image.network(
                      product.imageUrl!,
                      height: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppCard.elevated(
                child: Column(
                  children: [
                    _buildDetailRow('Calories', '${product.calories.round()} kcal', theme),
                    const Divider(height: AppSpacing.md),
                    _buildDetailRow('Protein', '${product.protein.round()}g', theme),
                    const Divider(height: AppSpacing.md),
                    _buildDetailRow('Carbs', '${product.carbohydrates.round()}g', theme),
                    const Divider(height: AppSpacing.md),
                    _buildDetailRow('Fat', '${product.fat.round()}g', theme),
                    const Divider(height: AppSpacing.md),
                    _buildDetailRow('Serving Size', product.servingSize, theme),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton.primary(
                label: 'Add to Nutrition Log',
                onPressed: () {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final entry = FoodLogEntry(
                    id: const Uuid().v4(),
                    date: today,
                    foodName: product.name,
                    serving: 1.0,
                    calories: product.calories,
                    protein: product.protein,
                    carbs: product.carbohydrates,
                    fat: product.fat,
                    createdAt: now,
                  );
                  ref.read(foodLogsProvider.notifier).addFoodLog(entry);
                  context.go('/food-scanner');
                  context.showSnack('Food added to diary', isSuccess: true);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.outlined(
                label: 'Scan Another',
                onPressed: () => context.pop(), // goes back to camera
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
