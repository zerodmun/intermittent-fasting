import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/app_button.dart';
import 'package:fast_flow/features/food/data/models/food_recognition_model.dart';
import 'package:fast_flow/features/food/data/models/food_log_entry.dart';
import 'package:fast_flow/features/food/presentation/providers/food_recognition_provider.dart';
import 'package:fast_flow/features/food/presentation/providers/food_logs_provider.dart';

import 'package:fast_flow/core/services/logger_service.dart';

class AiFoodResultScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final FoodRecognitionModel result;

  const AiFoodResultScreen({
    required this.imagePath,
    required this.result,
    super.key,
  });

  @override
  ConsumerState<AiFoodResultScreen> createState() => _AiFoodResultScreenState();
}

class _AiFoodResultScreenState extends ConsumerState<AiFoodResultScreen> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    LoggerService.d('[ResultScreen] Result initState');
  }

  @override
  void dispose() {
    LoggerService.d('[ResultScreen] Result dispose');
    super.dispose();
  }

  Future<void> _analyzeAnotherPhoto() async {
    LoggerService.d('[ResultScreen] Analyze Another Photo pressed');
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null) {
        LoggerService.d('[ResultScreen] Capture successful for another photo: ${image.path}');
        // Wait for camera animation to finish fully
        await Future.delayed(const Duration(milliseconds: 600));
        
        if (context.mounted) {
          try {
            ref.read(foodRecognitionProvider.notifier).reset();
          } catch (e, s) {
            LoggerService.e('[ResultScreen] Exception in resetting provider', e, s);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              LoggerService.d('[ResultScreen] Replacing current result screen with new photo preview');
              context.pushReplacement('/food-scanner/ai-preview', extra: image.path);
            }
          });
        }
      } else {
        LoggerService.d('[ResultScreen] Capture cancelled by user');
      }
    } catch (e, stack) {
      LoggerService.e('[ResultScreen] Exception in analyzeAnotherPhoto', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open camera: $e')),
        );
      }
    }
  }

  Future<void> _addFood() async {
    LoggerService.d('[ResultScreen] Add Food pressed');
    if (_isSaving) {
      LoggerService.w('[ResultScreen] Blocked duplicate save request');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final entry = FoodLogEntry(
        id: const Uuid().v4(),
        date: today,
        foodName: widget.result.name,
        serving: widget.result.estimatedWeightG.toDouble(),
        calories: widget.result.calories.toDouble(),
        protein: widget.result.protein.toDouble(),
        carbs: widget.result.carbs.toDouble(),
        fat: widget.result.fat.toDouble(),
        createdAt: now,
      );

      LoggerService.d('[ResultScreen] Saving entry to Hive database...');
      await ref.read(foodLogsProvider.notifier).addFoodLog(entry);
      LoggerService.d('[ResultScreen] Save completed');

      LoggerService.d('[ResultScreen] Refreshing related providers...');
      ref.invalidate(foodLogsProvider);
      ref.invalidate(fastingRecordsProvider);

      if (mounted) {
        LoggerService.d('[ResultScreen] Navigating back to food-scanner');
        context.go('/food-scanner');
        context.showSnack('Food added successfully.', isSuccess: true);
      }
    } catch (e, stack) {
      LoggerService.e('[ResultScreen] Exception in addFood', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add food log: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    LoggerService.d('[ResultScreen] Result build');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalMacros = widget.result.carbs + widget.result.protein + widget.result.fat;
    final carbsPercent = totalMacros > 0 ? widget.result.carbs / totalMacros : 0.0;
    final proteinPercent = totalMacros > 0 ? widget.result.protein / totalMacros : 0.0;
    final fatPercent = totalMacros > 0 ? widget.result.fat / totalMacros : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estimation Result'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                child: Container(
                  height: 220,
                  width: double.infinity,
                  color: colorScheme.surfaceContainerHighest,
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      LoggerService.e('[ResultScreen] Image.file failed to load', error, stackTrace);
                      return Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.result.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Estimated Weight: ${widget.result.estimatedWeightG}g',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Icon(
                              widget.result.confidence >= 0.6
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.warning_amber_rounded,
                              size: 16,
                              color: widget.result.confidence >= 0.6
                                  ? Colors.green
                                  : Colors.amber[800],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Confidence: ${(widget.result.confidence * 100).toInt()}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: widget.result.confidence >= 0.6
                                    ? Colors.green[700]
                                    : Colors.amber[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(
                      '🔥 ${widget.result.calories} kcal',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),

              if (widget.result.confidence < 0.6) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.amber[600]!),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber[800]!),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Low Confidence Estimate',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.amber[900]!,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'This result has low confidence. Please verify before saving.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.amber[950]!,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              AppCard.outlined(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Macronutrients',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _buildMacroRow(
                      context: context,
                      label: 'Carbohydrates',
                      value: '${widget.result.carbs}g',
                      percent: carbsPercent,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _buildMacroRow(
                      context: context,
                      label: 'Protein',
                      value: '${widget.result.protein}g',
                      percent: proteinPercent,
                      color: Colors.green,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _buildMacroRow(
                      context: context,
                      label: 'Fat',
                      value: '${widget.result.fat}g',
                      percent: fatPercent,
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xlg),

              AppButton.primary(
                label: _isSaving ? 'Saving...' : 'Add to Diary',
                icon: Icons.add_circle_outline_rounded,
                isFullWidth: true,
                onPressed: _isSaving ? null : () => _addFood(),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.outlined(
                label: 'Analyze Another Photo',
                icon: Icons.camera_alt_rounded,
                isFullWidth: true,
                onPressed: _isSaving ? null : () => _analyzeAnotherPhoto(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroRow({
    required BuildContext context,
    required String label,
    required String value,
    required double percent,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
