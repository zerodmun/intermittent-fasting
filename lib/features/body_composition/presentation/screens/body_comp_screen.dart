import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/constants/app_animations.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/app_button.dart';
import 'package:fast_flow/shared/widgets/app_input.dart';
import 'package:fast_flow/shared/widgets/app_dialog.dart';
import 'package:fast_flow/shared/widgets/app_bottom_sheet.dart';
import 'package:fast_flow/shared/widgets/body_silhouette.dart';
import 'package:fast_flow/shared/widgets/metric_change_badge.dart';
import 'package:fast_flow/shared/widgets/empty_state.dart';
import 'package:fast_flow/shared/widgets/shimmer_loading.dart';
import 'package:fast_flow/shared/widgets/section_header.dart';
import 'package:fast_flow/features/weight/domain/entities/weight_entry.dart';
import 'package:fast_flow/features/weight/presentation/providers/weight_providers.dart';
import 'package:fast_flow/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';
import 'package:fast_flow/features/body_composition/data/services/body_comp_service.dart';
import 'package:fast_flow/features/body_composition/presentation/providers/body_comp_providers.dart';
import 'package:fast_flow/features/body_composition/presentation/widgets/body_comp_widgets.dart';
import 'package:fast_flow/features/body_composition/domain/entities/body_comp_result.dart';
import 'package:fast_flow/features/body_composition/domain/entities/body_fat_category.dart';

class BodyCompScreen extends ConsumerStatefulWidget {
  const BodyCompScreen({super.key});

  @override
  ConsumerState<BodyCompScreen> createState() => _BodyCompScreenState();
}

class _BodyCompScreenState extends ConsumerState<BodyCompScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedChartMetric = 'Weight';
  String _selectedChartFilter = 'All Time';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(bodyCompEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Body Composition'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'History'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(context),
          _buildHistoryTab(context, entries),
          _buildTrendsTab(context, entries),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final profileAsync = ref.read(userProfileProvider);
          profileAsync.whenData((profile) {
            if (profile != null) {
              _showAddEntrySheet(context, null, profile);
            }
          });
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Log'),
      ),
    );
  }

  // ── Tab 1: Overview ──
  Widget _buildOverviewTab(BuildContext context) {
    final result = ref.watch(latestBodyCompResultProvider);
    final entry = ref.watch(latestBodyCompEntryProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (entry == null || result == null) {
      return const EmptyState(
        icon: Icons.scale_rounded,
        title: 'No measurements logged',
        subtitle: 'Log your first weight and body metrics to see analysis.',
      );
    }

    final profile = profileAsync.maybeWhen(
      data: (p) => p,
      orElse: () => null,
    );

    final gender = profile?.gender ?? 'male';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row containing circular BodyFatGauge and human CustomPaint BodySilhouette
          SizedBox(
            height: 230,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: AppCard.elevated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Stack(
                      children: [
                        Center(
                          child: BodyFatGauge(
                            bodyFatPercent: result.bodyFatPercentage,
                            category: result.category,
                          ),
                        ),
                        if (result.hasBodyFat)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: Icon(
                                Icons.info_outline_rounded,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                              onPressed: () => _showCalculationDetailSheet(
                                context,
                                result,
                                profile!,
                                entry,
                                gender,
                              ),
                              tooltip: 'Calculation Details',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 4,
                  child: AppCard.elevated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: result.hasBodyFat
                        ? BodySilhouette(
                            bodyFatPercent: result.bodyFatPercentage,
                            leanMassPercent: double.parse((100.0 - result.bodyFatPercentage).toStringAsFixed(1)),
                            fatMassPercent: double.parse(result.bodyFatPercentage.toStringAsFixed(1)),
                            gender: gender,
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.accessibility_new_rounded, size: 48, color: Colors.grey),
                                SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Log waist/neck to unlock avatar',
                                  style: TextStyle(fontSize: 10, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Alert Tip if Body Fat calculation inputs are missing
          if (!result.hasBodyFat) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Unlock Body Fat Analysis',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Log your neck, waist, and hip (for females) measurements to estimate your body fat % and lean mass using the official U.S. Navy Body Fat Formula.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Weight vs Goal Card
          if (profile != null) ...[
            AppCard.elevated(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Weight',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${entry.weightKg.toStringAsFixed(1)} kg',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Goal Weight',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${profile.goalWeightKg.toStringAsFixed(1)} kg',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: (entry.weightKg == profile.goalWeightKg)
                          ? 1.0
                          : (profile.goalWeightKg / entry.weightKg).clamp(0.0, 1.0),
                      backgroundColor: colorScheme.outlineVariant,
                      color: colorScheme.primary,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.weightKg > profile.goalWeightKg
                        ? '${(entry.weightKg - profile.goalWeightKg).toStringAsFixed(1)} kg above goal'
                        : '${(profile.goalWeightKg - entry.weightKg).toStringAsFixed(1)} kg below goal',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 2x2 Details Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.5,
            children: [
              _buildDetailCard(
                context,
                title: 'Lean Body Mass',
                value: result.hasBodyFat ? '${result.leanBodyMassKg.toStringAsFixed(1)} kg' : 'N/A',
                subtitle: 'Active tissue/muscle',
                color: theme.colorScheme.primary,
              ),
              _buildDetailCard(
                context,
                title: 'Fat Mass',
                value: result.hasBodyFat ? '${result.fatMassKg.toStringAsFixed(1)} kg' : 'N/A',
                subtitle: 'Stored body energy',
                color: theme.colorScheme.secondary,
              ),
              _buildDetailCard(
                context,
                title: 'BMI',
                value: result.bmi.toStringAsFixed(1),
                subtitle: _getBmiCategory(result.bmi),
                color: theme.colorScheme.tertiary,
              ),
              _buildDetailCard(
                context,
                title: 'Ideal Weight',
                value: '${result.idealWeightKg.toStringAsFixed(1)} kg',
                subtitle: 'Devine standard',
                color: context.colors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Circumferences & Tape Measurements Summary
          AppCard.outlined(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Circumference Measurements',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCircumferenceTile(context, 'Waist', entry.waistCm != null ? '${entry.waistCm} cm' : '--'),
                    _buildCircumferenceTile(context, 'Neck', entry.neckCm != null ? '${entry.neckCm} cm' : '--'),
                    if (gender.toLowerCase() == 'female')
                      _buildCircumferenceTile(context, 'Hip', entry.hipCm != null ? '${entry.hipCm} cm' : '--'),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
                Row(
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      color: context.colors.success,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Waist-to-Height Ratio: ${result.waistToHeightRatio.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            result.waistToHeightRatio <= 0.0
                                ? 'Awaiting waist circumference input'
                                : result.waistToHeightRatio < 0.5
                                    ? 'Healthy abdominal fat level'
                                    : 'Attention: higher abdominal fat range',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Daily Needs Card
          AppCard.outlined(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Daily Energy Needs',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _buildEnergyMetric(
                        context,
                        label: 'BMR',
                        value: '${result.bmr.round()} kcal',
                        desc: 'Energy burned at complete rest',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    Expanded(
                      child: _buildEnergyMetric(
                        context,
                        label: 'TDEE',
                        value: '${result.tdee.round()} kcal',
                        desc: 'Activity output (moderate multiplier)',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return AppCard.elevated(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCircumferenceTile(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
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

  Widget _buildEnergyMetric(
    BuildContext context, {
    required String label,
    required String value,
    required String desc,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal Weight';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  // ── Tab 2: History & Logs ──
  Widget _buildHistoryTab(BuildContext context, List<WeightEntry> entries) {
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'Empty log history',
        subtitle: 'Log a new measurement using the button below.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard.elevated(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              shape: const Border(),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${entry.weightKg.toStringAsFixed(1)} kg',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(entry.date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                entry.bodyFatPercentage != null
                    ? 'Fat: ${entry.bodyFatPercentage!.toStringAsFixed(1)}%  •  BMI: ${entry.bmi?.toStringAsFixed(1) ?? ""}'
                    : 'Only Weight logged',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              children: [
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCircumferenceSummary(context, entry),
                      if (entry.note != null && entry.note!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Note: ${entry.note}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: () {
                              final profileAsync = ref.read(userProfileProvider);
                              profileAsync.whenData((profile) {
                                if (profile != null) {
                                  _showAddEntrySheet(context, entry, profile);
                                }
                              });
                            },
                            icon: const Icon(Icons.edit_rounded),
                            color: theme.colorScheme.primary,
                          ),
                          IconButton(
                            onPressed: () => _confirmDeleteEntry(context, entry.id),
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: theme.colorScheme.error,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCircumferenceSummary(BuildContext context, WeightEntry entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final metrics = [
      if (entry.waistCm != null) MapEntry('Waist', '${entry.waistCm} cm'),
      if (entry.neckCm != null) MapEntry('Neck', '${entry.neckCm} cm'),
      if (entry.hipCm != null) MapEntry('Hip', '${entry.hipCm} cm'),
      if (entry.chestCm != null) MapEntry('Chest', '${entry.chestCm} cm'),
      if (entry.shoulderCm != null) MapEntry('Shoulder', '${entry.shoulderCm} cm'),
      if (entry.leftArmCm != null) MapEntry('L-Arm', '${entry.leftArmCm} cm'),
      if (entry.rightArmCm != null) MapEntry('R-Arm', '${entry.rightArmCm} cm'),
      if (entry.leftForearmCm != null) MapEntry('L-Forearm', '${entry.leftForearmCm} cm'),
      if (entry.rightForearmCm != null) MapEntry('R-Forearm', '${entry.rightForearmCm} cm'),
      if (entry.leftThighCm != null) MapEntry('L-Thigh', '${entry.leftThighCm} cm'),
      if (entry.rightThighCm != null) MapEntry('R-Thigh', '${entry.rightThighCm} cm'),
      if (entry.leftCalfCm != null) MapEntry('L-Calf', '${entry.leftCalfCm} cm'),
      if (entry.rightCalfCm != null) MapEntry('R-Calf', '${entry.rightCalfCm} cm'),
    ];

    if (metrics.isEmpty) {
      return Text(
        'No tape measurements logged for this date.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: metrics.map((m) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Text(
            '${m.key}: ${m.value}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Tab 3: Trends & Progress ──
  Widget _buildTrendsTab(BuildContext context, List<WeightEntry> entries) {
    final changes = ref.watch(bodyCompChangesProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.trending_up_rounded,
        title: 'No trends to show',
        subtitle: 'Log at least 2 entries to display progression charts.',
      );
    }

    final profile = profileAsync.maybeWhen(
      data: (p) => p,
      orElse: () => null,
    );

    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filter and map entries based on timeframe
    final filtered = _filterEntries(entries, _selectedChartFilter);
    final chartEntries = filtered.reversed.toList();
    
    final spots = <FlSpot>[];
    for (int i = 0; i < chartEntries.length; i++) {
      final val = _getMetricValue(chartEntries[i], _selectedChartMetric, profile);
      if (val != null) {
        spots.add(FlSpot(spots.length.toDouble(), val));
      }
    }

    final insights = _generateSmartInsights(entries, profile);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedChartMetric,
                  decoration: InputDecoration(
                    labelText: 'Metric',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Weight', child: Text('Weight')),
                    DropdownMenuItem(value: 'Body Fat', child: Text('Body Fat %')),
                    DropdownMenuItem(value: 'Lean Mass', child: Text('Lean Mass')),
                    DropdownMenuItem(value: 'Fat Mass', child: Text('Fat Mass')),
                    DropdownMenuItem(value: 'BMI', child: Text('BMI')),
                    DropdownMenuItem(value: 'Waist', child: Text('Waist')),
                    DropdownMenuItem(value: 'Chest', child: Text('Chest')),
                    DropdownMenuItem(value: 'Arms', child: Text('Arms (Avg)')),
                    DropdownMenuItem(value: 'Thighs', child: Text('Thighs (Avg)')),
                    DropdownMenuItem(value: 'Calves', child: Text('Calves (Avg)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedChartMetric = val;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedChartFilter,
                  decoration: InputDecoration(
                    labelText: 'Timeframe',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Weekly', child: Text('7 Days')),
                    DropdownMenuItem(value: 'Monthly', child: Text('30 Days')),
                    DropdownMenuItem(value: 'Yearly', child: Text('1 Year')),
                    DropdownMenuItem(value: 'All Time', child: Text('All Time')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedChartFilter = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Chart Display Card
          SectionHeader(title: '$_selectedChartMetric Progression'),
          AppCard.elevated(
            child: SizedBox(
              height: 220,
              child: spots.length < 2
                  ? Center(
                      child: Text(
                        'Awaiting more logs containing this measurement.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(right: 12, top: 12),
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 42,
                                getTitlesWidget: (val, meta) {
                                  return Text(
                                    val.toStringAsFixed(1),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget: (val, meta) {
                                  final idx = val.toInt();
                                  if (idx < 0 || idx >= chartEntries.length) return const SizedBox.shrink();
                                  final entry = chartEntries[idx];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      DateFormat('MM/dd').format(entry.date),
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 9,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: theme.colorScheme.primary,
                              barWidth: 3.5,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Smart Insights Card
          if (insights.isNotEmpty) ...[
            SectionHeader(title: 'Smart Insights'),
            AppCard.outlined(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.insights_rounded, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Observations & Tips',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...insights.map((ins) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                color: colorScheme.primary.withValues(alpha: 0.8), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ins,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Recent Progress Summary (Table)
          if (changes != null) ...[
            SectionHeader(title: 'Recent Changes'),
            AppCard.elevated(
              child: Column(
                children: [
                  _buildProgressRow(context, 'Weight', changes.weightChange, 'kg', isDecreaseSuccess: true),
                  if (changes.bodyFatChange != 0.0)
                    _buildProgressRow(context, 'Body Fat %', changes.bodyFatChange, '%', isDecreaseSuccess: true),
                  if (changes.leanMassChange != 0.0)
                    _buildProgressRow(context, 'Lean Mass', changes.leanMassChange, 'kg', isDecreaseSuccess: false),
                  if (changes.waistChange != 0.0)
                    _buildProgressRow(context, 'Waist', changes.waistChange, 'cm', isDecreaseSuccess: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressRow(
    BuildContext context,
    String label,
    double change,
    String unit, {
    required bool isDecreaseSuccess,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          MetricChangeBadge(
            change: change,
            unit: unit,
            isDecreaseSuccess: isDecreaseSuccess,
          ),
        ],
      ),
    );
  }

  // Helper getters for metric values & charts
  double? _getMetricValue(WeightEntry entry, String metric, UserProfile profile) {
    switch (metric) {
      case 'Weight':
        return entry.weightKg;
      case 'Body Fat':
        return entry.bodyFatPercentage;
      case 'Lean Mass':
        return entry.leanMassKg;
      case 'Fat Mass':
        return entry.fatMassKg;
      case 'BMI':
        return entry.bmi;
      case 'Waist':
        return entry.waistCm;
      case 'Chest':
        return entry.chestCm;
      case 'Arms':
        final l = entry.leftArmCm ?? 0.0;
        final r = entry.rightArmCm ?? 0.0;
        if (l > 0 && r > 0) return (l + r) / 2;
        if (l > 0) return l;
        if (r > 0) return r;
        return null;
      case 'Thighs':
        final l = entry.leftThighCm ?? 0.0;
        final r = entry.rightThighCm ?? 0.0;
        if (l > 0 && r > 0) return (l + r) / 2;
        if (l > 0) return l;
        if (r > 0) return r;
        return null;
      case 'Calves':
        final l = entry.leftCalfCm ?? 0.0;
        final r = entry.rightCalfCm ?? 0.0;
        if (l > 0 && r > 0) return (l + r) / 2;
        if (l > 0) return l;
        if (r > 0) return r;
        return null;
      default:
        return null;
    }
  }

  List<WeightEntry> _filterEntries(List<WeightEntry> entries, String filter) {
    final now = DateTime.now();
    final cutoff = switch (filter) {
      'Weekly' => now.subtract(const Duration(days: 7)),
      'Monthly' => now.subtract(const Duration(days: 30)),
      'Yearly' => now.subtract(const Duration(days: 365)),
      _ => null,
    };

    if (cutoff == null) return entries;
    return entries.where((e) => e.date.isAfter(cutoff)).toList();
  }

  List<String> _generateSmartInsights(List<WeightEntry> entries, UserProfile profile) {
    if (entries.isEmpty) return [];

    final insights = <String>[];
    final latest = entries.first;

    // 1. Goal Progress
    final goalDiff = (latest.weightKg - profile.goalWeightKg).abs();
    if (goalDiff <= 0.1) {
      insights.add('Congratulations! You have reached your target weight of ${profile.goalWeightKg} kg!');
    } else {
      final direction = latest.weightKg > profile.goalWeightKg ? 'lose' : 'gain';
      insights.add('You are ${goalDiff.toStringAsFixed(1)} kg away from your target weight of ${profile.goalWeightKg} kg (${direction} goal).');
    }

    if (entries.length < 2) return insights;

    final prev = entries[1];
    final latestComp = BodyCompService.calculate(
      profile: profile,
      weightKg: latest.weightKg,
      waistCm: latest.waistCm,
      neckCm: latest.neckCm,
      hipCm: latest.hipCm,
    );
    final prevComp = BodyCompService.calculate(
      profile: profile,
      weightKg: prev.weightKg,
      waistCm: prev.waistCm,
      neckCm: prev.neckCm,
      hipCm: prev.hipCm,
    );

    // 2. Recent Weight change
    final weightDiff = latest.weightKg - prev.weightKg;
    if (weightDiff != 0.0) {
      final verb = weightDiff < 0 ? 'decreased' : 'increased';
      insights.add('Weight has ${verb} by ${weightDiff.abs().toStringAsFixed(1)} kg since your last entry.');
    }

    // 3. Body Fat & Lean Mass
    if (latestComp.hasBodyFat && prevComp.hasBodyFat) {
      final bfDiff = latestComp.bodyFatPercentage - prevComp.bodyFatPercentage;
      if (bfDiff != 0.0) {
        final verb = bfDiff < 0 ? 'decreased' : 'increased';
        insights.add('Body Fat percentage has ${verb} by ${bfDiff.abs().toStringAsFixed(1)}% since your last entry.');
      }

      final lmDiff = latestComp.leanBodyMassKg - prevComp.leanBodyMassKg;
      if (lmDiff > 0.1) {
        insights.add('Lean Body Mass increased by ${lmDiff.toStringAsFixed(1)} kg! Great job building muscle tissue.');
      } else if (lmDiff < -0.1) {
        insights.add('Lean Body Mass decreased by ${lmDiff.abs().toStringAsFixed(1)} kg. Make sure to consume enough protein.');
      }

      // Recomposition
      if (weightDiff.abs() < 0.5 && bfDiff < -0.5) {
        insights.add('Body Recomposition detected! Weight is steady, but body fat improved by ${bfDiff.abs().toStringAsFixed(1)}%, indicating positive fat loss and muscle gain.');
      }
    }

    // 4. Waist Circumference
    if (latest.waistCm != null && prev.waistCm != null) {
      final waistDiff = latest.waistCm! - prev.waistCm!;
      if (waistDiff != 0.0) {
        final verb = waistDiff < 0 ? 'reduced' : 'increased';
        insights.add('Waist circumference ${verb} by ${waistDiff.abs().toStringAsFixed(1)} cm.');
      }
    }

    return insights;
  }

  // ── Bottom Sheet calculation detail ──
  void _showCalculationDetailSheet(
    BuildContext context,
    BodyCompResult result,
    UserProfile profile,
    WeightEntry latestEntry,
    String gender,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMale = gender.toLowerCase() == 'male';

    AppBottomSheet.show(
      context: context,
      title: 'Calculation Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'U.S. Navy Body Fat Formula',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Text(
              isMale
                  ? 'BF% = 495 / (1.0324 - 0.19077 × log10(Waist - Neck) + 0.15456 × log10(Height)) - 450'
                  : 'BF% = 495 / (1.29579 - 0.35004 × log10(Waist + Hip - Neck) + 0.22100 × log10(Height)) - 450',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Input Values Used',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildInputRow(context, 'Height', '${profile.heightCm} cm'),
          _buildInputRow(context, 'Weight', '${latestEntry.weightKg} kg'),
          if (latestEntry.waistCm != null) _buildInputRow(context, 'Waist Circumference', '${latestEntry.waistCm} cm'),
          if (latestEntry.neckCm != null) _buildInputRow(context, 'Neck Circumference', '${latestEntry.neckCm} cm'),
          if (latestEntry.hipCm != null && !isMale) _buildInputRow(context, 'Hip Circumference', '${latestEntry.hipCm} cm'),
          const Divider(height: AppSpacing.lg),
          Text(
            'Calculated Result',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Body Fat Percentage', style: theme.textTheme.bodyMedium),
              Text(
                '${result.bodyFatPercentage.toStringAsFixed(1)}%',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Body Fat Category', style: theme.textTheme.bodyMedium),
              BodyFatCategoryBadge(category: result.category),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Healthy Range', style: theme.textTheme.bodyMedium),
              Text(
                result.category.getHealthyRange(gender),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xlg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: colorScheme.error.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'This body fat percentage is an estimation based on the official U.S. Navy Body Fat Formula and should not replace professional medical or body composition analysis.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Add/Edit bottom sheet trigger ──
  void _showAddEntrySheet(BuildContext context, WeightEntry? existing, UserProfile profile) {
    AppBottomSheet.show(
      context: context,
      title: existing == null ? 'Log New Measurements' : 'Edit Log Entry',
      child: _AddEditEntrySheet(
        profile: profile,
        existing: existing,
        onSave: (entry) {
          if (existing == null) {
            ref.read(weightProvider.notifier).addEntry(entry);
          } else {
            ref.read(weightProvider.notifier).updateEntry(entry);
          }
        },
      ),
    );
  }

  void _confirmDeleteEntry(BuildContext context, String id) async {
    final confirm = await AppDialog.showConfirm(
      context: context,
      title: 'Delete Entry',
      content: 'Are you sure you want to permanently delete this logged measurement?',
      isDestructive: true,
    );

    if (confirm == true) {
      ref.read(weightProvider.notifier).deleteEntry(id);
      if (context.mounted) {
        context.showSnack('Measurement deleted', isSuccess: true);
      }
    }
  }
}

// ── Private stateful widget for input sheet ──
class _AddEditEntrySheet extends StatefulWidget {
  final UserProfile profile;
  final WeightEntry? existing;
  final Function(WeightEntry) onSave;

  const _AddEditEntrySheet({
    required this.profile,
    required this.existing,
    required this.onSave,
  });

  @override
  State<_AddEditEntrySheet> createState() => _AddEditEntrySheetState();
}

class _AddEditEntrySheetState extends State<_AddEditEntrySheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _weightController;
  late final TextEditingController _waistController;
  late final TextEditingController _neckController;
  late final TextEditingController _hipController;
  late final TextEditingController _chestController;
  late final TextEditingController _shoulderController;
  late final TextEditingController _leftArmController;
  late final TextEditingController _rightArmController;
  late final TextEditingController _leftForearmController;
  late final TextEditingController _rightForearmController;
  late final TextEditingController _leftThighController;
  late final TextEditingController _rightThighController;
  late final TextEditingController _leftCalfController;
  late final TextEditingController _rightCalfController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _weightController = TextEditingController(text: e?.weightKg.toString() ?? '');
    _waistController = TextEditingController(text: e?.waistCm?.toString() ?? '');
    _neckController = TextEditingController(text: e?.neckCm?.toString() ?? '');
    _hipController = TextEditingController(text: e?.hipCm?.toString() ?? '');
    _chestController = TextEditingController(text: e?.chestCm?.toString() ?? '');
    _shoulderController = TextEditingController(text: e?.shoulderCm?.toString() ?? '');
    _leftArmController = TextEditingController(text: e?.leftArmCm?.toString() ?? '');
    _rightArmController = TextEditingController(text: e?.rightArmCm?.toString() ?? '');
    _leftForearmController = TextEditingController(text: e?.leftForearmCm?.toString() ?? '');
    _rightForearmController = TextEditingController(text: e?.rightForearmCm?.toString() ?? '');
    _leftThighController = TextEditingController(text: e?.leftThighCm?.toString() ?? '');
    _rightThighController = TextEditingController(text: e?.rightThighCm?.toString() ?? '');
    _leftCalfController = TextEditingController(text: e?.leftCalfCm?.toString() ?? '');
    _rightCalfController = TextEditingController(text: e?.rightCalfCm?.toString() ?? '');
    _noteController = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _weightController.dispose();
    _waistController.dispose();
    _neckController.dispose();
    _hipController.dispose();
    _chestController.dispose();
    _shoulderController.dispose();
    _leftArmController.dispose();
    _rightArmController.dispose();
    _leftForearmController.dispose();
    _rightForearmController.dispose();
    _leftThighController.dispose();
    _rightThighController.dispose();
    _leftCalfController.dispose();
    _rightCalfController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _validateWeight(String? val) {
    if (val == null || val.isEmpty) return 'Weight is required';
    final weight = double.tryParse(val);
    if (weight == null) return 'Must be a valid number';
    if (weight <= 20) return 'Weight must be greater than 20 kg';
    return null;
  }

  String? _validateWaist(String? val) {
    if (val == null || val.isEmpty) {
      if (_neckController.text.isNotEmpty) {
        return 'Waist is required if Neck is entered';
      }
      return null;
    }
    final waist = double.tryParse(val);
    if (waist == null) return 'Must be a valid number';
    if (waist <= 0) return 'Must be greater than 0';

    final neck = double.tryParse(_neckController.text);
    if (widget.profile.gender.toLowerCase() == 'male') {
      if (neck != null && waist <= neck) {
        return 'Waist must be greater than Neck';
      }
    } else {
      final hip = double.tryParse(_hipController.text);
      if (neck != null && hip != null && (waist + hip) <= neck) {
        return 'Waist + Hip must be greater than Neck';
      }
    }
    return null;
  }

  String? _validateNeck(String? val) {
    if (val == null || val.isEmpty) {
      if (_waistController.text.isNotEmpty) {
        return 'Neck is required if Waist is entered';
      }
      return null;
    }
    final neck = double.tryParse(val);
    if (neck == null) return 'Must be a valid number';
    if (neck <= 0) return 'Must be greater than 0';

    final waist = double.tryParse(_waistController.text);
    if (widget.profile.gender.toLowerCase() == 'male') {
      if (waist != null && waist <= neck) {
        return 'Neck must be smaller than Waist';
      }
    } else {
      final hip = double.tryParse(_hipController.text);
      if (waist != null && hip != null && (waist + hip) <= neck) {
        return 'Neck must be smaller than Waist + Hip';
      }
    }
    return null;
  }

  String? _validateHip(String? val) {
    if (widget.profile.gender.toLowerCase() != 'female') return null;
    if (val == null || val.isEmpty) {
      if (_waistController.text.isNotEmpty || _neckController.text.isNotEmpty) {
        return 'Hip is required for female body fat calculation';
      }
      return null;
    }
    final hip = double.tryParse(val);
    if (hip == null) return 'Must be a valid number';
    if (hip <= 0) return 'Must be greater than 0';

    final waist = double.tryParse(_waistController.text);
    final neck = double.tryParse(_neckController.text);
    if (waist != null && neck != null && (waist + hip) <= neck) {
      return 'Waist + Hip must be greater than Neck';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMale = widget.profile.gender.toLowerCase() == 'male';

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    label: 'Weight (kg)',
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateWeight,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppInput(
                    label: 'Waist (cm)',
                    controller: _waistController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateWaist,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    label: 'Neck (cm)',
                    controller: _neckController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateNeck,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                if (!isMale)
                  Expanded(
                    child: AppInput(
                      label: 'Hips (cm)',
                      controller: _hipController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: _validateHip,
                    ),
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Tape Circumferences Expansion
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  'Additional Tape Measurements',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                tilePadding: EdgeInsets.zero,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppInput(
                          label: 'Chest (cm)',
                          controller: _chestController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppInput(
                          label: 'Shoulders (cm)',
                          controller: _shoulderController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppInput(
                          label: 'Left Arm (cm)',
                          controller: _leftArmController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppInput(
                          label: 'Right Arm (cm)',
                          controller: _rightArmController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppInput(
                          label: 'Left Forearm (cm)',
                          controller: _leftForearmController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppInput(
                          label: 'Right Forearm (cm)',
                          controller: _rightForearmController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppInput(
                          label: 'Left Thigh (cm)',
                          controller: _leftThighController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppInput(
                          label: 'Right Thigh (cm)',
                          controller: _rightThighController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppInput(
                          label: 'Left Calf (cm)',
                          controller: _leftCalfController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppInput(
                          label: 'Right Calf (cm)',
                          controller: _rightCalfController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            AppInput(
              label: 'Notes',
              controller: _noteController,
              hint: 'How did you feel today?',
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.xlg),
            AppButton.primary(
              label: 'Save Measurement',
              isFullWidth: true,
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  if (widget.profile.heightCm <= 100) {
                    context.showSnack('Profile height must be greater than 100 cm', isSuccess: false);
                    return;
                  }
                  final weight = double.parse(_weightController.text);
                  final waist = double.tryParse(_waistController.text);
                  final neck = double.tryParse(_neckController.text);
                  final hip = double.tryParse(_hipController.text);

                  // Compute body composition
                  final compResult = BodyCompService.calculate(
                    profile: widget.profile,
                    weightKg: weight,
                    waistCm: waist,
                    neckCm: neck,
                    hipCm: hip,
                  );

                  final entry = WeightEntry(
                    id: widget.existing?.id ?? const Uuid().v4(),
                    weightKg: weight,
                    date: widget.existing?.date ?? DateTime.now(),
                    bodyFatPercentage: compResult.hasBodyFat ? compResult.bodyFatPercentage : null,
                    leanMassKg: compResult.hasBodyFat ? compResult.leanBodyMassKg : null,
                    fatMassKg: compResult.hasBodyFat ? compResult.fatMassKg : null,
                    bmi: compResult.bmi,
                    bmr: compResult.bmr,
                    tdee: compResult.tdee,
                    waistCm: waist,
                    neckCm: neck,
                    hipCm: hip,
                    chestCm: double.tryParse(_chestController.text),
                    shoulderCm: double.tryParse(_shoulderController.text),
                    leftArmCm: double.tryParse(_leftArmController.text),
                    rightArmCm: double.tryParse(_rightArmController.text),
                    leftForearmCm: double.tryParse(_leftForearmController.text),
                    rightForearmCm: double.tryParse(_rightForearmController.text),
                    leftThighCm: double.tryParse(_leftThighController.text),
                    rightThighCm: double.tryParse(_rightThighController.text),
                    leftCalfCm: double.tryParse(_leftCalfController.text),
                    rightCalfCm: double.tryParse(_rightCalfController.text),
                    note: _noteController.text,
                    createdAt: widget.existing?.createdAt ?? DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  widget.onSave(entry);
                  Navigator.of(context).pop();
                  context.showSnack('Entry saved successfully', isSuccess: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
