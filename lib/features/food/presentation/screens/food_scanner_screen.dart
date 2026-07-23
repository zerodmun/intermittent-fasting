import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/app_button.dart';

import 'package:fast_flow/core/services/logger_service.dart';

class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    LoggerService.d('[FoodScanner] initState');
    _retrieveLostData();
  }

  Future<void> _retrieveLostData() async {
    LoggerService.d('[FoodScanner] Checking for lost camera data...');
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      LoggerService.d('[FoodScanner] LostDataResponse: type=${response.type}, file=${response.file?.path}');
      if (response.isEmpty) {
        LoggerService.d('[FoodScanner] No lost data found');
        return;
      }
      if (response.file != null) {
        final path = response.file!.path;
        LoggerService.d('[FoodScanner] Retrieved lost image path: $path');
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          LoggerService.d('[FoodScanner] Lost image file exists, size: $size bytes');
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                LoggerService.d('[FoodScanner] Opening Preview for retrieved image via context.go');
                context.go('/food-scanner/ai-preview', extra: path);
              }
            });
          }
        } else {
          LoggerService.d('[FoodScanner] Lost image file does not exist on disk');
        }
      } else if (response.exception != null) {
        LoggerService.w('[FoodScanner] ImagePicker retrieved lost data error: ${response.exception}');
      }
    } catch (e, stack) {
      LoggerService.e('[FoodScanner] Exception in _retrieveLostData', e, stack);
    }
  }

  Future<void> _scanRealFood(BuildContext context) async {
    if (_isProcessing) {
      LoggerService.w('[FoodScanner] Double tap prevented');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      LoggerService.d('[FoodScanner] Camera opened');
      LoggerService.d('[FoodScanner] Capture started');
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      LoggerService.d('[FoodScanner] Capture finished');
      if (image != null) {
        LoggerService.d('[FoodScanner] Image path: ${image.path}');
        final file = File(image.path);
        final exists = await file.exists();
        LoggerService.d('[FoodScanner] Image exists: $exists');
        if (exists) {
          final size = await file.length();
          LoggerService.d('[FoodScanner] Image size: $size bytes');
        }

        LoggerService.d('[FoodScanner] Leaving Camera');
        // Delay to let native camera transition close fully
        await Future.delayed(const Duration(milliseconds: 600));

        if (context.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              LoggerService.d('[FoodScanner] Opening Preview via context.go');
              context.go('/food-scanner/ai-preview', extra: image.path);
            }
          });
        } else {
          LoggerService.w('[FoodScanner] Context not mounted after camera exit');
        }
      } else {
        LoggerService.d('[FoodScanner] Image capture cancelled by user');
      }
    } catch (e, stack) {
      LoggerService.e('[FoodScanner] Exception in camera capture', e, stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    LoggerService.d('[FoodScanner] build');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Scanner'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Information Card
              AppCard.outlined(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Scanner Information',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Currently, Fomo IF supports scanning packaged foods using barcodes registered in the Open Food Facts database. AI food recognition from photos is currently under development and will be available in a future update.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Card 1: Barcode Scanner
              AppCard.outlined(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.qr_code_scanner_rounded,
                            size: AppSpacing.iconLg,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scan Barcode',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Scan a product\'s barcode to search and add it to your logs.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton.primary(
                      label: 'Scan Barcode',
                      icon: Icons.qr_code_scanner_rounded,
                      isFullWidth: true,
                      onPressed: () => context.push('/food-scanner/camera'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Card 2: Scan Real Food (AI)
              AppCard.outlined(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.restaurant_rounded,
                            size: AppSpacing.iconLg,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scan Real Food (AI)',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Take a photo of your meal. AI will estimate food name and nutrition.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton.primary(
                      label: _isProcessing ? 'Capturing...' : 'Scan Real Food',
                      icon: Icons.restaurant_rounded,
                      isFullWidth: true,
                      onPressed: _isProcessing ? null : () => _scanRealFood(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
