# Food Scanner Module Architecture

This module is completely isolated to support independent development of the food scanner features in the future.

## Directory Structure
- `presentation/pages/` - Contains the user interface views (e.g., `FoodScannerScreen`).
- `presentation/widgets/` - Future custom widgets (camera overlays, scanning overlays, chart lists).
- `providers/` - Riverpod state management and notification providers.
- `models/` - Data models for scanned meals, nutrition facts, and calories.
- `services/` - AI recognition services, camera controllers, and local storage.
- `repositories/` - Data abstraction layers for saving scan records.
- `domain/` - Business logic and use cases.

## Future Ready Roadmap
- **Take Photo**: Integration with camera system.
- **Choose Image**: Retrieve photos from gallery.
- **AI Food Recognition**: Deep learning recognition model to classify items.
- **Calorie Estimation**: Direct weight/volume estimations of scanned items.
- **Macronutrients**: Display proteins, fats, carbs metrics.
- **Micronutrients**: Vitamin & mineral estimation.
- **Meal History**: Log previous scans to local database.
- **Barcode Scanner**: Scan UPC/EAN barcodes.
- **Nutrition Facts**: OCR scanner to read nutritional labels.
- **Daily Calorie Tracking**: Interlock with body composition goals and weight trackers.
