import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/shared/widgets/app_button.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/shimmer_loading.dart';
import 'package:fast_flow/features/food/presentation/providers/food_recognition_provider.dart';

import 'package:fast_flow/core/services/logger_service.dart';

class AiCameraPreviewScreen extends ConsumerStatefulWidget {
  final String imagePath;
  const AiCameraPreviewScreen({required this.imagePath, super.key});

  @override
  ConsumerState<AiCameraPreviewScreen> createState() => _AiCameraPreviewScreenState();
}

class _AiCameraPreviewScreenState extends ConsumerState<AiCameraPreviewScreen> {
  late String _currentImagePath;

  @override
  void initState() {
    super.initState();
    LoggerService.d('[PreviewScreen] Preview initState');
    _currentImagePath = widget.imagePath;

    // Reset the provider state immediately on entry to prevent state leakage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LoggerService.d('[PreviewScreen] Resetting foodRecognitionProvider state');
      try {
        ref.read(foodRecognitionProvider.notifier).reset();
      } catch (e, stack) {
        LoggerService.e('[PreviewScreen] Exception in resetting provider', e, stack);
      }
    });
  }

  @override
  void dispose() {
    LoggerService.d('[PreviewScreen] Preview dispose');
    super.dispose();
  }

  Future<void> _retakeImage() async {
    LoggerService.d('[PreviewScreen] Retake button pressed');
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null) {
        LoggerService.d('[PreviewScreen] New photo path: ${image.path}');
        final file = File(image.path);
        final exists = await file.exists();
        if (exists) {
          final size = await file.length();
          LoggerService.d('[PreviewScreen] New photo exists, size: $size bytes');
        }
        try {
          ref.read(foodRecognitionProvider.notifier).reset();
        } catch (e, s) {
          LoggerService.e('[PreviewScreen] Exception in resetting provider during retake', e, s);
        }
        setState(() {
          _currentImagePath = image.path;
        });
      } else {
        LoggerService.d('[PreviewScreen] Retake cancelled by user');
      }
    } catch (e, stack) {
      LoggerService.e('[PreviewScreen] Exception in retake', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open camera: $e')),
        );
      }
    }
  }

  Future<void> _analyzeMeal() async {
    LoggerService.d('[PreviewScreen] Analyze Nutrition button pressed');
    final currentState = ref.read(foodRecognitionProvider);
    if (currentState.isLoading) {
      LoggerService.w('[PreviewScreen] Blocked duplicate analysis request');
      return;
    }

    try {
      LoggerService.d('[PreviewScreen] Launching Gemini analysis for $_currentImagePath');
      final notifier = ref.read(foodRecognitionProvider.notifier);
      await notifier.recognize(_currentImagePath);
      LoggerService.d('[PreviewScreen] recognize completed');
    } catch (e, stack) {
      LoggerService.e('[PreviewScreen] Exception during analyzeMeal recognize', e, stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    LoggerService.d('[PreviewScreen] Preview build');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recognitionState = ref.watch(foodRecognitionProvider);
    final isLoading = recognitionState.isLoading;
    final hasError = recognitionState.hasError;

    // Set up reactive listener for navigation to decouple state updates from button triggers
    ref.listen<AsyncValue>(
      foodRecognitionProvider,
      (previous, next) {
        LoggerService.d('[PreviewScreen] foodRecognitionProvider state transition: previous=$previous, next=$next');
        if (next is AsyncData) {
          final result = next.value;
          if (result != null && mounted) {
            LoggerService.d('[PreviewScreen] Navigation target ready, opening Result Screen');
            context.pushReplacement(
              '/food-scanner/ai-result',
              extra: {
                'imagePath': _currentImagePath,
                'result': result,
              },
            );
          }
        }
      },
    );

    LoggerService.d('[PreviewScreen] Buttons initialized');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Meal'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        child: Container(
                          color: colorScheme.surfaceContainerHighest,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              const ShimmerLoading(
                                width: double.infinity,
                                height: double.infinity,
                              ),
                              Image.file(
                                File(_currentImagePath),
                                fit: BoxFit.cover,
                                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                  if (wasSynchronouslyLoaded) return child;
                                  return AnimatedOpacity(
                                    opacity: frame == null ? 0 : 1,
                                    duration: const Duration(milliseconds: 450),
                                    curve: Curves.easeIn,
                                    child: child,
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  LoggerService.e('[PreviewScreen] Image.file failed to load', error, stackTrace);
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
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (hasError) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppCard.outlined(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: colorScheme.error),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Unable to analyze this photo.',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    'Please make sure you have internet and retry, or try another photo.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isLoading) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppCard.outlined(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Analyzing your food...',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    'Estimating nutrition... Please wait.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton.primary(
                    label: isLoading ? 'Analyzing...' : 'Analyze Nutrition',
                    icon: Icons.analytics_rounded,
                    isFullWidth: true,
                    onPressed: isLoading ? null : _analyzeMeal,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton.outlined(
                    label: 'Retake Photo',
                    icon: Icons.camera_alt_rounded,
                    isFullWidth: true,
                    onPressed: isLoading ? null : _retakeImage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
