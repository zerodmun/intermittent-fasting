import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/constants/app_animations.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/app_button.dart';
import 'package:fast_flow/shared/widgets/empty_state.dart';

class ProgressPhotosScreen extends StatefulWidget {
  const ProgressPhotosScreen({super.key});

  @override
  State<ProgressPhotosScreen> createState() => _ProgressPhotosScreenState();
}

class _ProgressPhotosScreenState extends State<ProgressPhotosScreen> {
  final ImagePicker _picker = ImagePicker();
  Map<String, String> _photoPaths = {};

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('photo_'));
    final Map<String, String> paths = {};
    for (final k in keys) {
      final val = prefs.getString(k);
      if (val != null && File(val).existsSync()) {
        paths[k.replaceFirst('photo_', '')] = val;
      }
    }
    setState(() {
      _photoPaths = paths;
    });
  }

  Future<void> _capturePhoto(String slot) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1440,
        imageQuality: 85,
      );

      if (image == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final photoDir = Directory('${appDir.path}/progress_photos');
      if (!photoDir.existsSync()) {
        photoDir.createSync();
      }

      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final localFile = File('${photoDir.path}/${slot}_$dateStr.jpg');
      await File(image.path).copy(localFile.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('photo_$slot', localFile.path);

      _loadPhotos();
      if (mounted) {
        context.showSnack('Photo saved successfully', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        context.showSnack('Failed to capture photo: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Photos'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Visual Progression',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Track changes in your physique over time.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: AppSpacing.xlg),

            // Grid of 4 photo slots: Front, Back, Left, Right
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.75,
              children: [
                _buildPhotoSlot('front', 'Front View'),
                _buildPhotoSlot('back', 'Back View'),
                _buildPhotoSlot('left', 'Left Side'),
                _buildPhotoSlot('right', 'Right Side'),
              ],
            ),
            SizedBox(height: AppSpacing.xxl),

            if (_photoPaths.isNotEmpty)
              AppButton.outlined(
                label: 'Clear All Photos',
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  for (final k in _photoPaths.keys) {
                    await prefs.remove('photo_$k');
                  }
                  _loadPhotos();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSlot(String slot, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final path = _photoPaths[slot];

    return AppCard.elevated(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: path != null
                ? ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppSpacing.radiusLg),
                    ),
                    child: Image.file(
                      File(path),
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppSpacing.radiusLg),
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: AppSpacing.iconXl * 1.5,
                      color: colorScheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: () => _capturePhoto(slot),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  color: colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
