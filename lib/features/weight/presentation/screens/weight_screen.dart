import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/constants/app_animations.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/features/weight/domain/entities/weight_entry.dart';
import 'package:fast_flow/features/weight/presentation/providers/weight_providers.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/app_button.dart';
import 'package:fast_flow/shared/widgets/app_input.dart';
import 'package:fast_flow/shared/widgets/app_dialog.dart';
import 'package:fast_flow/shared/widgets/app_bottom_sheet.dart';
import 'package:fast_flow/shared/widgets/empty_state.dart';
import 'package:fast_flow/shared/widgets/section_header.dart';
import 'package:fast_flow/shared/widgets/shimmer_loading.dart';
import 'package:fast_flow/shared/widgets/metric_change_badge.dart';
import 'package:fast_flow/features/body_composition/data/services/body_comp_service.dart';

class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(weightProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Tracker'),
      ),
      body: profileAsync.when(
        loading: () => const _LoadingWeightScreen(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();

          final latest = entries.isNotEmpty ? entries.first : null;
          final previous = entries.length > 1 ? entries[1] : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Goal Card
                AppCard.elevated(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Weight',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    latest != null ? '${latest.weightKg.toStringAsFixed(1)} kg' : '-- kg',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (latest != null && previous != null) ...[
                                    const SizedBox(width: 8),
                                    MetricChangeBadge(
                                      change: latest.weightKg - previous.weightKg,
                                      unit: 'kg',
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Goal Weight',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${profile.goalWeightKg.toStringAsFixed(1)} kg',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        child: LinearProgressIndicator(
                          value: latest != null
                              ? _calculateProgress(latest.weightKg, profile.weightKg, profile.goalWeightKg)
                              : 0.0,
                          minHeight: 8,
                          backgroundColor: colorScheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        latest != null
                            ? '${(latest.weightKg - profile.goalWeightKg).abs().toStringAsFixed(1)} kg remaining to reach goal'
                            : 'Log your first weight entry.',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Link to full Body Composition analysis
                AppCard.gradient(
                  gradient: context.colors.fastingGradient,
                  onTap: () => context.push('/home/body-composition'),
                  child: Row(
                    children: [
                      Icon(
                        Icons.insights_rounded,
                        color: colorScheme.onPrimary,
                        size: 32,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Full Body Composition Analysis',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                            Text(
                              'View body fat %, lean mass, silhouette, and charts.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimary.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.onPrimary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Weight Logs Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Weight Logs',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppButton.text(
                      label: 'Log Weight',
                      size: AppButtonSize.sm,
                      onPressed: () => _showAddEntrySheet(context, ref, profile, null),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                if (entries.isEmpty)
                  const EmptyState(
                    icon: Icons.scale_outlined,
                    title: 'No logs yet',
                    subtitle: 'Add entries to start monitoring your weight progress.',
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, idx) {
                      final entry = entries[idx];
                      return AppCard.elevated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.weightKg.toStringAsFixed(1)} kg',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(entry.date),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => _showAddEntrySheet(context, ref, profile, entry),
                                  icon: const Icon(Icons.edit_rounded),
                                  color: colorScheme.primary,
                                  visualDensity: VisualDensity.compact,
                                ),
                                IconButton(
                                  onPressed: () => _confirmDeleteEntry(context, ref, entry.id),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  color: colorScheme.error,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _calculateProgress(double current, double start, double goal) {
    if (start == goal) return 1.0;
    final total = start - goal;
    final done = start - current;
    if (total == 0) return 0.0;
    return (done / total).clamp(0.0, 1.0);
  }

  void _confirmDeleteEntry(BuildContext context, WidgetRef ref, String id) async {
    final confirm = await AppDialog.showConfirm(
      context: context,
      title: 'Delete Entry',
      content: 'Are you sure you want to permanently delete this logged weight?',
      isDestructive: true,
    );

    if (confirm == true) {
      await ref.read(weightProvider.notifier).deleteEntry(id);
      if (context.mounted) {
        context.showSnack('Entry deleted');
      }
    }
  }

  void _showAddEntrySheet(BuildContext context, WidgetRef ref, UserProfile profile, WeightEntry? existing) {
    final isEdit = existing != null;
    final weightController = TextEditingController(text: existing?.weightKg.toString() ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');
    final formKey = GlobalKey<FormState>();

    AppBottomSheet.show(
      context: context,
      title: isEdit ? 'Edit Weight Log' : 'Log New Weight',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInput(
              label: 'Weight (kg)',
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (val) => (val == null || double.tryParse(val) == null) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppInput(
              label: 'Note',
              controller: noteController,
              hint: 'Optional notes',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: 'Save Log',
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final weight = double.parse(weightController.text);
                  
                  // Run body comp calculations automatically so other tabs stay populated
                  final compResult = BodyCompService.calculate(
                    profile: profile,
                    weightKg: weight,
                    waistCm: existing?.waistCm,
                    neckCm: existing?.neckCm,
                    hipCm: existing?.hipCm,
                  );

                  final entry = WeightEntry(
                    id: existing?.id ?? const Uuid().v4(),
                    weightKg: weight,
                    date: existing?.date ?? DateTime.now(),
                    bodyFatPercentage: compResult.bodyFatPercentage,
                    leanMassKg: compResult.leanBodyMassKg,
                    fatMassKg: compResult.fatMassKg,
                    bmi: compResult.bmi,
                    bmr: compResult.bmr,
                    tdee: compResult.tdee,
                    waistCm: existing?.waistCm,
                    neckCm: existing?.neckCm,
                    hipCm: existing?.hipCm,
                    note: noteController.text,
                  );

                  if (isEdit) {
                    ref.read(weightProvider.notifier).updateEntry(entry);
                  } else {
                    ref.read(weightProvider.notifier).addEntry(entry);
                  }

                  Navigator.of(context).pop();
                  context.showSnack('Weight entry logged', isSuccess: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingWeightScreen extends StatelessWidget {
  const _LoadingWeightScreen();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        children: const [
          ShimmerLoading(width: double.infinity, height: 130),
          SizedBox(height: AppSpacing.md),
          ShimmerLoading(width: double.infinity, height: 80),
          SizedBox(height: AppSpacing.lg),
          ShimmerLoading(width: double.infinity, height: 300),
        ],
      ),
    );
  }
}
