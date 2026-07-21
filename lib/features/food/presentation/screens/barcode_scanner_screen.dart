import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/shared/widgets/app_button.dart';
import 'package:fast_flow/core/services/food_api_service.dart';
import 'package:fast_flow/features/food/data/models/food_product.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  MobileScannerController? _controller;
  bool _isProcessing = false;
  bool _isLoading = false;
  bool _notFound = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeScan(String barcode) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _isLoading = true;
    });

    // Pause the camera stream to stop rendering/streaming
    await _controller?.stop();

    try {
      final product = await FoodSearchService.searchByBarcode(barcode);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (product != null) {
        // Push result screen and wait for pop back
        await context.push('/food-scanner/result', extra: product);

        if (mounted) {
          _resetScanner();
        }
      } else {
        setState(() {
          _notFound = true;
        });
      }
    } on OfflineException catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = 'No internet connection. Please check your settings.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = 'Food not found or an error occurred.';
        });
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _isProcessing = false;
      _isLoading = false;
      _notFound = false;
      _errorText = null;
    });
    _controller?.start();
  }

  Widget _buildLoadingView() {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Product Barcode'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Searching food...',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Not Found'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Product Not Found',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              "We couldn't find this product in our database. Please scan another product or try again.",
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton.primary(
              label: 'Scan Another',
              onPressed: _resetScanner,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton.outlined(
              label: 'Go Back',
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Scanning Error',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton.primary(
              label: 'Retry Scan',
              onPressed: _resetScanner,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton.outlined(
              label: 'Go Back',
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingView();
    }
    if (_notFound) {
      return _buildNotFoundView();
    }
    if (_errorText != null) {
      return _buildErrorView(_errorText!);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Product Barcode'),
        centerTitle: true,
        actions: [
          if (_controller != null) ...[
            IconButton(
              icon: ValueListenableBuilder<MobileScannerState>(
                valueListenable: _controller!,
                builder: (context, state, child) {
                  switch (state.torchState) {
                    case TorchState.off:
                      return const Icon(Icons.flash_off_rounded);
                    case TorchState.on:
                      return const Icon(Icons.flash_on_rounded, color: Colors.amber);
                    default:
                      return const Icon(Icons.flash_off_rounded);
                  }
                },
              ),
              onPressed: () => _controller!.toggleTorch(),
            ),
            IconButton(
              icon: ValueListenableBuilder<MobileScannerState>(
                valueListenable: _controller!,
                builder: (context, state, child) {
                  switch (state.cameraDirection) {
                    case CameraFacing.front:
                      return const Icon(Icons.camera_front_rounded);
                    case CameraFacing.back:
                      return const Icon(Icons.camera_rear_rounded);
                    default:
                      return const Icon(Icons.camera_rear_rounded);
                  }
                },
              ),
              onPressed: () => _controller!.switchCamera(),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          if (_controller != null)
            MobileScanner(
              controller: _controller!,
              onDetect: (capture) {
                if (_isProcessing) return;
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final barcodeValue = barcodes.first.rawValue;
                  if (barcodeValue != null && barcodeValue.isNotEmpty) {
                    _handleBarcodeScan(barcodeValue);
                  }
                }
              },
            ),
          // Scanner Overlay Guide
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final scanAreaSize = width * 0.75;
                final top = (height - scanAreaSize) / 2;

                return Stack(
                  children: [
                    // Semi-transparent overlay around the scan area
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.5),
                        BlendMode.srcOut,
                      ),
                      child: Stack(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: scanAreaSize,
                              height: scanAreaSize * 0.6,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Border around the scan area
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: scanAreaSize,
                        height: scanAreaSize * 0.6,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.primary,
                            width: 3.0,
                          ),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                    ),
                    // Scanning text
                    Positioned(
                      top: top - 50,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          'Align barcode within the frame',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
