import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:fast_flow/core/constants/app_colors.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/core/helpers/body_comp_calculator.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/features/onboarding/models/user_profile.dart';
import 'package:fast_flow/features/weight/models/weight_entry.dart';
import 'package:fast_flow/features/weight/providers/weight_provider.dart';
import 'package:fast_flow/features/home/providers/home_provider.dart';
import 'package:fast_flow/shared/widgets/animated_progress_ring.dart';
import 'package:fast_flow/shared/widgets/empty_state.dart';

class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  int _activeTab = 0; // 0 = Dashboard, 1 = Charts, 2 = Logs
  String _chartMetric = 'Weight'; // Weight, Body Fat, Lean Mass, Fat Mass, BMI, Waist, Neck, Hip
  String _chartRange = 'Monthly'; // Weekly, Monthly, Yearly, All Time

  // Form Controllers
  final _weightController = TextEditingController();
  final _waistController = TextEditingController();
  final _neckController = TextEditingController();
  final _hipController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _weightController.dispose();
    _waistController.dispose();
    _neckController.dispose();
    _hipController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final entries = ref.watch(weightProvider);
    final compResult = ref.watch(currentBodyCompProvider);

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Body Composition'),
        ),
        body: const EmptyState(
          icon: Icons.monitor_weight,
          title: 'No user profile',
          subtitle: 'Please complete onboarding first.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Body Composition'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Log Measurements',
            onPressed: () => _showAddEntrySheet(context, profile),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Dashboard')),
                ButtonSegment(value: 1, label: Text('Charts')),
                ButtonSegment(value: 2, label: Text('Logs')),
              ],
              selected: {_activeTab},
              onSelectionChanged: (set) {
                setState(() {
                  _activeTab = set.first;
                });
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildActiveTabContent(profile, entries, compResult),
            ),
          ),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent(
    UserProfile profile,
    List<WeightEntry> entries,
    BodyCompResult? comp,
  ) {
    if (entries.isEmpty) {
      return const EmptyState(
        key: ValueKey('empty_entries'),
        icon: Icons.monitor_weight_outlined,
        title: 'No data recorded yet',
        subtitle: 'Log your weight and circumferences to estimate body fat.',
        illustrationPath: 'assets/illustrations/empty_weight.svg',
      );
    }

    switch (_activeTab) {
      case 1:
        return _buildChartsTab(profile, entries);
      case 2:
        return _buildLogsTab(profile, entries);
      case 0:
      default:
        return _buildDashboardTab(profile, entries, comp);
    }
  }

  // ── DASHBOARD TAB ──
  Widget _buildDashboardTab(UserProfile profile, List<WeightEntry> entries, BodyCompResult? comp) {
    final latest = entries.first;
    final isFemale = profile.gender.toLowerCase() == 'female';

    return SingleChildScrollView(
      key: const ValueKey('dashboard_tab'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Circular progress comparison card
          if (comp != null) _buildCircularVisualCard(comp, isFemale),
          const SizedBox(height: AppSpacing.md),

          // Core Metrics Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.5,
            children: [
              _buildMetricCard('Weight', '${latest.weightKg.toStringAsFixed(1)} kg', 'Goal: ${profile.goalWeightKg.toStringAsFixed(1)} kg'),
              _buildMetricCard(
                'Body Fat',
                latest.bodyFatPercentage != null ? '${latest.bodyFatPercentage!.toStringAsFixed(1)}%' : '--',
                'Goal: ${profile.targetBodyFat.toStringAsFixed(1)}%',
              ),
              _buildMetricCard(
                'Lean Mass',
                latest.leanMassKg != null ? '${latest.leanMassKg!.toStringAsFixed(1)} kg' : '--',
                'Muscle & bone',
              ),
              _buildMetricCard(
                'Fat Mass',
                latest.fatMassKg != null ? '${latest.fatMassKg!.toStringAsFixed(1)} kg' : '--',
                'Adipose tissue',
              ),
              _buildMetricCard(
                'BMI',
                latest.bmi != null ? latest.bmi!.toStringAsFixed(1) : '--',
                'Goal: ${profile.targetBmi.toStringAsFixed(1)}',
              ),
              _buildMetricCard(
                'Waist',
                latest.waistCm != null ? '${latest.waistCm!.toStringAsFixed(1)} cm' : '--',
                'Goal: ${profile.targetWaist.toStringAsFixed(1)} cm',
              ),
              _buildMetricCard('Neck', latest.neckCm != null ? '${latest.neckCm!.toStringAsFixed(1)} cm' : '--', 'Circumference'),
              if (isFemale)
                _buildMetricCard('Hip', latest.hipCm != null ? '${latest.hipCm!.toStringAsFixed(1)} cm' : '--', 'Widest point'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Daily Needs Card
          if (comp != null) _buildDailyNeedsCard(comp),
          const SizedBox(height: AppSpacing.md),

          // Progress statistics
          _buildProgressStatisticsCard(entries),
          const SizedBox(height: AppSpacing.md),

          // Goal Adjuster
          _buildGoalsEditorCard(profile),
        ],
      ),
    );
  }

  Widget _buildCircularVisualCard(BodyCompResult comp, bool isFemale) {
    Color fatColor;
    switch (comp.categoryIndex) {
      case 0:
        fatColor = Colors.blue;
        break;
      case 1:
      case 2:
        fatColor = AppColors.success;
        break;
      case 3:
        fatColor = AppColors.warning;
        break;
      case 4:
      default:
        fatColor = AppColors.error;
        break;
    }

    final fatRatio = comp.bodyFatPercentage / 100.0;
    final leanRatio = comp.leanBodyMassKg / (comp.leanBodyMassKg + comp.fatMassKg);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    AnimatedProgressRing(
                      progress: fatRatio,
                      size: 90,
                      strokeWidth: 8,
                      color: fatColor,
                      child: Text(
                        '${comp.bodyFatPercentage}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Body Fat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                Column(
                  children: [
                    AnimatedProgressRing(
                      progress: leanRatio,
                      size: 90,
                      strokeWidth: 8,
                      color: AppColors.success,
                      child: Text(
                        '${(leanRatio * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Lean Mass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: fatColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
              ),
              child: Text(
                'Category: ${comp.bodyFatCategory}',
                style: TextStyle(color: fatColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isFemale
                  ? 'Healthy female range: 21% - 31%'
                  : 'Healthy male range: 14% - 24%',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, String subtitle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              val,
              style: context.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyNeedsCard(BodyCompResult comp) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Energy Expenditure estimations', style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BMR (Basal Metabolism)', style: TextStyle(fontSize: 12)),
                    Text('${comp.bmr.toStringAsFixed(0)} kcal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('TDEE (Daily Needs)', style: TextStyle(fontSize: 12)),
                    Text('${comp.tdee.toStringAsFixed(0)} kcal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.colorScheme.primary)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStatisticsCard(List<WeightEntry> entries) {
    final first = entries.last;
    final latest = entries.first;

    final weightDiff = first.weightKg - latest.weightKg;
    final bfDiff = (first.bodyFatPercentage ?? 0.0) - (latest.bodyFatPercentage ?? 0.0);
    final leanDiff = (latest.leanMassKg ?? 0.0) - (first.leanMassKg ?? 0.0);
    final days = latest.date.difference(first.date).inDays;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Progress Metrics', style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            _buildProgressRow('Weight Change', '${weightDiff >= 0 ? '-' : '+'}${weightDiff.abs().toStringAsFixed(1)} kg'),
            _buildProgressRow('Body Fat Reduced', '${bfDiff.toStringAsFixed(1)}%'),
            _buildProgressRow('Lean Mass Change', '${leanDiff >= 0 ? '+' : ''}${leanDiff.toStringAsFixed(1)} kg'),
            _buildProgressRow('Days Tracked', '$days days'),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildGoalsEditorCard(UserProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Goal Progress', style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showEditGoalsDialog(context, profile),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildGoalProgress('Weight Goal', profile.weightKg, profile.goalWeightKg, 'kg'),
            _buildGoalProgress('Body Fat Goal', 25.0, profile.targetBodyFat, '%'),
            _buildGoalProgress('Waist Goal', 90.0, profile.targetWaist, 'cm'),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalProgress(String label, double current, double target, String unit) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              Text('Target: ${target.toStringAsFixed(1)} $unit', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: progress, borderRadius: BorderRadius.circular(4)),
        ],
      ),
    );
  }

  // ── CHARTS TAB ──
  Widget _buildChartsTab(UserProfile profile, List<WeightEntry> entries) {
    final isFemale = profile.gender.toLowerCase() == 'female';

    return SingleChildScrollView(
      key: const ValueKey('charts_tab'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<String>(
                value: _chartMetric,
                onChanged: (val) {
                  if (val != null) setState(() => _chartMetric = val);
                },
                items: [
                  'Weight',
                  'Body Fat',
                  'Lean Mass',
                  'Fat Mass',
                  'BMI',
                  'Waist',
                  'Neck',
                  if (isFemale) 'Hip',
                ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              ),
              DropdownButton<String>(
                value: _chartRange,
                onChanged: (val) {
                  if (val != null) setState(() => _chartRange = val);
                },
                items: ['Weekly', 'Monthly', 'Yearly', 'All Time']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildTrendLineChart(entries),
        ],
      ),
    );
  }

  Widget _buildTrendLineChart(List<WeightEntry> entries) {
    final filtered = List<WeightEntry>.from(entries)..sort((a, b) => a.date.compareTo(b.date));

    if (filtered.length < 2) {
      return Card(
        child: Container(
          height: 220,
          alignment: Alignment.center,
          child: const Text('Add more measurements to see trends.'),
        ),
      );
    }

    final spots = List.generate(filtered.length, (idx) {
      final entry = filtered[idx];
      double val = 0.0;
      switch (_chartMetric) {
        case 'Body Fat':
          val = entry.bodyFatPercentage ?? 0.0;
          break;
        case 'Lean Mass':
          val = entry.leanMassKg ?? 0.0;
          break;
        case 'Fat Mass':
          val = entry.fatMassKg ?? 0.0;
          break;
        case 'BMI':
          val = entry.bmi ?? 0.0;
          break;
        case 'Waist':
          val = entry.waistCm ?? 0.0;
          break;
        case 'Neck':
          val = entry.neckCm ?? 0.0;
          break;
        case 'Hip':
          val = entry.hipCm ?? 0.0;
          break;
        case 'Weight':
        default:
          val = entry.weightKg;
          break;
      }
      return FlSpot(idx.toDouble(), val);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text('$_chartMetric History Trend', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < filtered.length) {
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(DateFormat('MMM d').format(filtered[idx].date), style: const TextStyle(fontSize: 8)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: context.colorScheme.primary,
                      barWidth: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── LOGS TAB ──
  Widget _buildLogsTab(UserProfile profile, List<WeightEntry> entries) {
    final isFemale = profile.gender.toLowerCase() == 'female';

    return ListView.builder(
      key: const ValueKey('logs_tab'),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Card(
          child: ListTile(
            leading: Icon(Icons.monitor_weight, color: context.colorScheme.primary),
            title: Text(
              '${entry.weightKg.toStringAsFixed(1)} kg • Fat: ${entry.bodyFatPercentage?.toStringAsFixed(1) ?? '--'}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${DateFormat('MMM d, h:mm a').format(entry.date)}\nWaist: ${entry.waistCm ?? '--'} cm • Neck: ${entry.neckCm ?? '--'} cm${isFemale ? ' • Hip: ${entry.hipCm ?? "--"} cm' : ''}${entry.note != null ? '\nNote: ${entry.note}' : ''}',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _showAddEntrySheet(context, profile, entry),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Entry'),
                        content: const Text('Are you sure you want to delete this measurement entry?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () {
                              ref.read(weightProvider.notifier).deleteEntry(entry.id);
                              Navigator.pop(context);
                            },
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Text(
        'Body fat percentage is an estimation based on the U.S. Navy formula and should not replace professional body composition analysis.',
        style: context.textTheme.labelSmall?.copyWith(
          color: context.colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 9,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Add/Edit sheets & dialogs
  void _showAddEntrySheet(BuildContext context, UserProfile profile, [WeightEntry? existing]) {
    final isFemale = profile.gender.toLowerCase() == 'female';

    if (existing != null) {
      _weightController.text = existing.weightKg.toString();
      _waistController.text = existing.waistCm?.toString() ?? '';
      _neckController.text = existing.neckCm?.toString() ?? '';
      _hipController.text = existing.hipCm?.toString() ?? '';
      _noteController.text = existing.note ?? '';
      _selectedDate = existing.date;
    } else {
      _weightController.clear();
      _waistController.clear();
      _neckController.clear();
      _hipController.clear();
      _noteController.clear();
      _selectedDate = DateTime.now();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing != null ? 'Edit Measurements' : 'Log Measurements',
                    style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Weight (kg)', suffixText: 'kg'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _waistController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Waist Circumference (cm)', suffixText: 'cm'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _neckController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Neck Circumference (cm)', suffixText: 'cm'),
                  ),
                  if (isFemale) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _hipController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Hip Circumference (cm)', suffixText: 'cm'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: () {
                      final w = double.tryParse(_weightController.text);
                      final waist = double.tryParse(_waistController.text);
                      final neck = double.tryParse(_neckController.text);
                      final hip = double.tryParse(_hipController.text);

                      if (w != null && w > 0 && waist != null && waist > 0 && neck != null && neck > 0) {
                        if (existing != null) {
                          ref.read(weightProvider.notifier).updateEntry(
                                existing.id,
                                w,
                                note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
                                date: _selectedDate,
                                waistCm: waist,
                                neckCm: neck,
                                hipCm: isFemale ? hip : null,
                              );
                        } else {
                          ref.read(weightProvider.notifier).addEntry(
                                w,
                                note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
                                date: _selectedDate,
                                waistCm: waist,
                                neckCm: neck,
                                hipCm: isFemale ? hip : null,
                              );
                        }
                        Navigator.pop(context);
                        context.showSnack('Measurements saved.');
                      } else {
                        context.showSnack('Please complete weight, waist, and neck values.', isError: true);
                      }
                    },
                    child: const Text('Save Measurements'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditGoalsDialog(BuildContext context, UserProfile profile) {
    final gWeight = TextEditingController(text: profile.goalWeightKg.toString());
    final gFat = TextEditingController(text: profile.targetBodyFat.toString());
    final gWaist = TextEditingController(text: profile.targetWaist.toString());
    final gBmi = TextEditingController(text: profile.targetBmi.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Targets & Goals'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: gWeight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Target Weight (kg)', suffixText: 'kg'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: gFat,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Target Body Fat %', suffixText: '%'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: gWaist,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Target Waist (cm)', suffixText: 'cm'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: gBmi,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Target BMI'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final w = double.tryParse(gWeight.text) ?? profile.goalWeightKg;
              final f = double.tryParse(gFat.text) ?? profile.targetBodyFat;
              final wa = double.tryParse(gWaist.text) ?? profile.targetWaist;
              final b = double.tryParse(gBmi.text) ?? profile.targetBmi;

              final updated = profile.copyWith(
                goalWeightKg: w,
                targetBodyFat: f,
                targetWaist: wa,
                targetBmi: b,
              );
              await HiveService.instance.saveUserProfile(updated);
              // Trigger UI refresh
              ref.invalidate(userProfileProvider);
              if (context.mounted) {
                Navigator.pop(context);
                context.showSnack('Goals updated successfully.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
