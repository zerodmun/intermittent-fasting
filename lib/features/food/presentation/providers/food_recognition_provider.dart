import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/features/food/data/models/food_recognition_model.dart';
import 'package:fast_flow/features/food/domain/repositories/food_recognition_repository.dart';

final foodRecognitionRepositoryProvider = Provider<FoodRecognitionRepository>((ref) {
  return FoodRecognitionRepository();
});

class FoodRecognitionNotifier extends Notifier<AsyncValue<FoodRecognitionModel?>> {
  late final FoodRecognitionRepository _repository;

  @override
  AsyncValue<FoodRecognitionModel?> build() {
    _repository = ref.watch(foodRecognitionRepositoryProvider);
    return const AsyncData(null);
  }

  Future<void> recognize(String imagePath) async {
    if (state.isLoading) return;

    state = const AsyncLoading();
    try {
      final result = await _repository.recognizeMeal(imagePath);
      state = AsyncData(result);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  void reset() {
    state = const AsyncData(null);
  }
}

final foodRecognitionProvider = NotifierProvider<FoodRecognitionNotifier, AsyncValue<FoodRecognitionModel?>>(
  FoodRecognitionNotifier.new,
);
