import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_spacing.dart';
import 'package:fast_flow/features/food_scanner/providers/food_logs_provider.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';

class FoodIntakeSummaryScreen extends ConsumerWidget {
  const FoodIntakeSummaryScreen({super.key});

  // Pre-defined mock foods for quick scanning/logging simulator
  static final List<Map<String, dynamic>> _mockPresets = [
    {
      'name': 'Avocado Toast with Egg',
      'calories': 380.0,
      'protein': 14.0,
      'fat': 22.0,
      'carbs': 32.0,
      'fiber': 7.0,
    },
    {
      'name': 'Grilled Chicken & Quinoa Salad',
      'calories': 480.0,
      'protein': 38.0,
      'fat': 12.0,
      'carbs': 45.0,
      'fiber': 8.0,
    },
    {
      'name': 'Whey Protein & Banana Shake',
      'calories': 290.0,
      'protein': 27.0,
      'fat': 3.0,
      'carbs': 38.0,
      'fiber': 3.0,
    },
    {
      'name': 'Baked Salmon & Broccoli',
      'calories': 420.0,
      'protein': 35.0,
      'fat': 20.0,
      'carbs': 15.0,
      'fiber': 5.0,
    },
    {
      'name': 'Greek Yogurt with Berries & Honey',
      'calories': 240.0,
      'protein': 18.0,
      'fat': 4.0,
      'carbs': 28.0,
      'fiber': 4.0,
    },
  ];

  void _showAddFoodDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: AppSpacing.screenPadding,
            right: AppSpacing.screenPadding,
            top: AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Log Scanned Food',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Simulate a food scanner detection or add a custom entry below.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Scanner Detections (Presets)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._mockPresets.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard.outlined(
                      onTap: () {
                        final entry = FoodLogEntry(
                          id: const Uuid().v4(),
                          name: p['name'] as String,
                          calories: p['calories'] as double,
                          protein: p['protein'] as double,
                          fat: p['fat'] as double,
                          carbs: p['carbs'] as double,
                          fiber: p['fiber'] as double,
                          date: DateTime.now(),
                        );
                        ref.read(foodLogsProvider.notifier).addFoodLog(entry);
                        Navigator.pop(context);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name'] as String,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'P: ${p['protein']}g  •  F: ${p['fat']}g  •  C: ${p['carbs']}g  •  Fb: ${p['fiber']}g',
                                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${(p['calories'] as double).toInt()} kcal',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodLogs = ref.watch(foodLogsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate totals
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalFat = 0.0;
    double totalCarbs = 0.0;
    double totalFiber = 0.0;

    for (final log in foodLogs) {
      totalCalories += log.calories;
      totalProtein += log.protein;
      totalFat += log.fat;
      totalCarbs += log.carbs;
      totalFiber += log.fiber;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Intake Summary'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Simulate Scanner Log',
            onPressed: () => _showAddFoodDialog(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: foodLogs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const EmptyState(
                      icon: Icons.no_food_outlined,
                      title: 'No food records yet.',
                      subtitle: 'Simulate scanning food to populate statistics.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      onPressed: () => _showAddFoodDialog(context, ref),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Scan Mock Food'),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Totals summary card
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: AppCard.elevated(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Daily Totals Summary',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${totalCalories.round()} kcal',
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    'Total Calories',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${foodLogs.length}',
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'Foods Logged',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: AppSpacing.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMacroMini(context, 'Protein', '${totalProtein.round()}g', Colors.redAccent),
                              _buildMacroMini(context, 'Fat', '${totalFat.round()}g', Colors.orangeAccent),
                              _buildMacroMini(context, 'Carbs', '${totalCarbs.round()}g', Colors.blueAccent),
                              _buildMacroMini(context, 'Fiber', '${totalFiber.round()}g', Colors.teal),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: Text(
                      'Logged Meal History',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                      itemCount: foodLogs.length,
                      itemBuilder: (context, index) {
                        final log = foodLogs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard.elevated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log.name,
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'P: ${log.protein.round()}g • F: ${log.fat.round()}g • C: ${log.carbs.round()}g • Fb: ${log.fiber.round()}g',
                                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${log.calories.round()} kcal',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    GestureDetector(
                                      onTap: () {
                                        ref.read(foodLogsProvider.notifier).deleteFoodLog(log.id);
                                      },
                                      child: Text(
                                        'Remove',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: colorScheme.error,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: foodLogs.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showAddFoodDialog(context, ref),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan Food'),
            )
          : null,
    );
  }

  Widget _buildMacroMini(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
