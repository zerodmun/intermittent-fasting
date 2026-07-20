import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/data/services/hive_service.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../food_scanner/providers/food_logs_provider.dart';
import '../../food_scanner/services/food_search_service.dart';
import '../../onboarding/domain/entities/user_profile.dart';

class FoodIntakeSummaryScreen extends ConsumerStatefulWidget {
  const FoodIntakeSummaryScreen({super.key});

  @override
  ConsumerState<FoodIntakeSummaryScreen> createState() => _FoodIntakeSummaryScreenState();
}

class _FoodIntakeSummaryScreenState extends ConsumerState<FoodIntakeSummaryScreen> {
  DateTime _selectedDate = DateTime.now();

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _getDateHeader() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    
    final difference = selected.difference(today).inDays;
    if (difference == 0) {
      return 'Today';
    } else if (difference == -1) {
      return 'Yesterday';
    } else if (difference == 1) {
      return 'Tomorrow';
    }
    return DateFormat('EEEE, MMM d').format(_selectedDate);
  }

  int _calculateCalorieRequirement(UserProfile? profile) {
    int dailyCalories = 2000;
    if (profile != null) {
      final isMale = profile.gender.toLowerCase() == 'male';
      final bmr = isMale
          ? 10.0 * profile.weightKg + 6.25 * profile.heightCm - 5.0 * profile.ageYears + 5.0
          : 10.0 * profile.weightKg + 6.25 * profile.heightCm - 5.0 * profile.ageYears - 161.0;

      final activity = HiveService.instance.getSetting<String>('pref_activity_level') ?? 'Lightly Active';
      double multiplier = 1.375;
      switch (activity) {
        case 'Sedentary': multiplier = 1.2; break;
        case 'Lightly Active': multiplier = 1.375; break;
        case 'Moderately Active': multiplier = 1.55; break;
        case 'Very Active': multiplier = 1.725; break;
        case 'Extra Active': multiplier = 1.9; break;
      }

      final tdee = bmr * multiplier;
      String defaultGoal = 'Maintain Weight';
      if (profile.goalWeightKg < profile.weightKg) {
        defaultGoal = 'Lose Weight';
      } else if (profile.goalWeightKg > profile.weightKg) {
        defaultGoal = 'Gain Weight';
      }
      final goal = HiveService.instance.getSetting<String>('pref_weight_goal') ?? defaultGoal;
      double adjustment = 0.0;
      if (goal == 'Lose Weight') {
        adjustment = -500.0;
      } else if (goal == 'Gain Weight') {
        adjustment = 500.0;
      }

      dailyCalories = (tdee + adjustment).clamp(1200.0, 5000.0).round();
    }
    return dailyCalories;
  }

  void _showEditServingDialog(FoodLogEntry log) {
    final controller = TextEditingController(text: log.serving.toString());
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Serving Size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Food: ${log.foodName}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              AppInput(
                label: 'Serving multiplier',
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                hint: 'e.g. 1.0',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newServing = double.tryParse(controller.text) ?? 1.0;
                if (newServing > 0) {
                  final baseCalories = log.calories / log.serving;
                  final baseProtein = log.protein / log.serving;
                  final baseCarbs = log.carbs / log.serving;
                  final baseFat = log.fat / log.serving;

                  final updated = FoodLogEntry(
                    id: log.id,
                    date: log.date,
                    foodName: log.foodName,
                    serving: newServing,
                    calories: baseCalories * newServing,
                    protein: baseProtein * newServing,
                    carbs: baseCarbs * newServing,
                    fat: baseFat * newServing,
                    createdAt: log.createdAt,
                  );

                  ref.read(foodLogsProvider.notifier).updateFoodLog(updated);
                  Navigator.pop(context);
                  context.showSnack('Serving updated', isSuccess: true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showSearchFoodBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (context) {
        return _SearchFoodSheet(
          selectedDate: _selectedDate,
          onFoodLogged: () {
            setState(() {}); // refresh totals if needed
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final foodLogs = ref.watch(foodLogsProvider);
    final profileAsync = ref.watch(userProfileProvider);

    // Selected day's logs (chronological by createdAt ascending)
    final dayLogs = foodLogs.where((log) =>
        log.date.year == _selectedDate.year &&
        log.date.month == _selectedDate.month &&
        log.date.day == _selectedDate.day).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Calculate totals for selected day
    double dayCalories = 0.0;
    double dayProtein = 0.0;
    double dayCarbs = 0.0;
    double dayFat = 0.0;
    for (final log in dayLogs) {
      dayCalories += log.calories;
      dayProtein += log.protein;
      dayCarbs += log.carbs;
      dayFat += log.fat;
    }

    final targetCalories = profileAsync.maybeWhen(
      data: _calculateCalorieRequirement,
      orElse: () => 2000,
    );

    final progress = targetCalories > 0 ? (dayCalories / targetCalories).clamp(0.0, 1.0) : 0.0;

    // Recalculate statistics from all Hive data
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Today's Calories
    double todayCalories = 0.0;
    for (final log in foodLogs) {
      if (log.date.year == todayStart.year &&
          log.date.month == todayStart.month &&
          log.date.day == todayStart.day) {
        todayCalories += log.calories;
      }
    }

    // 7-day total
    final start7 = todayStart.subtract(const Duration(days: 6));
    double total7DayCalories = 0.0;
    for (final log in foodLogs) {
      if (!log.date.isBefore(start7)) {
        total7DayCalories += log.calories;
      }
    }

    // 30-day total
    final start30 = todayStart.subtract(const Duration(days: 29));
    double total30DayCalories = 0.0;
    for (final log in foodLogs) {
      if (!log.date.isBefore(start30)) {
        total30DayCalories += log.calories;
      }
    }

    // Monthly total (current calendar month)
    final startMonth = DateTime(now.year, now.month, 1);
    double totalMonthlyCalories = 0.0;
    for (final log in foodLogs) {
      if (!log.date.isBefore(startMonth)) {
        totalMonthlyCalories += log.calories;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Total Calories Consumed'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date Switcher Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
              color: colorScheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _changeDate(-1),
                  ),
                  TextButton(
                    onPressed: _pickDate,
                    child: Text(
                      _getDateHeader(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => _changeDate(1),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  // Selected Day's Totals summary card
                  AppCard.elevated(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Nutrition Summary',
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
                                  '${dayCalories.round()} / $targetCalories kcal',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  'Daily Calories Consumed',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: colorScheme.surfaceVariant.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMacroMini(context, 'Protein', '${dayProtein.round()}g', Colors.redAccent),
                            _buildMacroMini(context, 'Carbs', '${dayCarbs.round()}g', Colors.blueAccent),
                            _buildMacroMini(context, 'Fat', '${dayFat.round()}g', Colors.orangeAccent),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Statistics Historical summaries section
                  Text(
                    'Calorie History Summaries',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppCard.elevated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${todayCalories.round()} kcal',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Today',
                                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppCard.elevated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${total7DayCalories.round()} kcal',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '7-Day Total',
                                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppCard.elevated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${total30DayCalories.round()} kcal',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '30-Day Total',
                                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppCard.elevated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${totalMonthlyCalories.round()} kcal',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Monthly Total',
                                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Chronological Daily Food List Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daily Food List',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${dayLogs.length} items',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (dayLogs.isEmpty)
                    const EmptyState(
                      icon: Icons.no_food_outlined,
                      title: 'No food entries today.',
                      subtitle: 'Use search below to log foods.',
                    )
                  else
                    ...dayLogs.map((log) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: AppCard.elevated(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            onTap: () => _showEditServingDialog(log),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log.foodName,
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'P: ${log.protein.round()}g • C: ${log.carbs.round()}g • F: ${log.fat.round()}g (Qty: ${log.serving})',
                                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${log.calories.round()} kcal',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () {
                                        ref.read(foodLogsProvider.notifier).deleteFoodLog(log.id);
                                        context.showSnack('Food entry deleted', isSuccess: true);
                                      },
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSearchFoodBottomSheet,
        icon: const Icon(Icons.search_rounded),
        label: const Text('Search Food'),
      ),
    );
  }

  Widget _buildMacroMini(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _SearchFoodSheet extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final VoidCallback onFoodLogged;

  const _SearchFoodSheet({
    required this.selectedDate,
    required this.onFoodLogged,
  });

  @override
  ConsumerState<_SearchFoodSheet> createState() => _SearchFoodSheetState();
}

class _SearchFoodSheetState extends ConsumerState<_SearchFoodSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<FoodProduct> _results = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products = await FoodSearchService.searchByName(trimmed);
      if (mounted) {
        setState(() {
          _results = products;
          _isLoading = false;
        });
      }
    } on OfflineException catch (_) {
      if (mounted) {
        setState(() {
          _results = [];
          _errorMessage = 'No internet connection.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _errorMessage = 'No food found.';
          _isLoading = false;
        });
      }
    }
  }

  void _showConfirmAddDialog(FoodProduct product) {
    final controller = TextEditingController(text: '1.0');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Food Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(product.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              if (product.brand.isNotEmpty) Text(product.brand, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              AppInput(
                label: 'Choose serving amount',
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                hint: 'e.g. 1.0',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final qty = double.tryParse(controller.text) ?? 1.0;
                if (qty > 0) {
                  final now = DateTime.now();
                  final entry = FoodLogEntry(
                    id: const Uuid().v4(),
                    date: widget.selectedDate,
                    foodName: product.name,
                    serving: qty,
                    calories: product.calories * qty,
                    protein: product.protein * qty,
                    carbs: product.carbohydrates * qty,
                    fat: product.fat * qty,
                    createdAt: now,
                  );

                  ref.read(foodLogsProvider.notifier).addFoodLog(entry);
                  Navigator.pop(context); // close confirm dialog
                  Navigator.pop(context); // close bottom sheet
                  widget.onFoodLogged();
                  context.showSnack('Food added to diary', isSuccess: true);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Search Food',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          AppInput(
            label: 'Search by food name',
            controller: _searchController,
            hint: 'e.g. Chicken Breast',
            onChanged: _onSearchChanged,
            prefix: const Icon(Icons.search_rounded),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: _isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: CircularProgressIndicator()))
                : _errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                          ),
                        ),
                      )
                    : _searchController.text.trim().isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Center(
                              child: Text(
                                'Type a food name to search online...',
                                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                          )
                        : _results.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(AppSpacing.lg),
                                child: Center(
                                  child: Text('No food found.'),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _results.length,
                                itemBuilder: (context, index) {
                                  final product = _results[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    onTap: () => _showConfirmAddDialog(product),
                                    title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      'P: ${product.protein.round()}g • C: ${product.carbohydrates.round()}g • F: ${product.fat.round()}g (${product.servingSize})',
                                    ),
                                    trailing: Text(
                                      '${product.calories.round()} kcal',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  );
                                },
                              ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
