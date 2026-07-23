import 'package:fast_flow/core/services/gemini_service.dart';
import 'package:fast_flow/features/food/data/models/food_recognition_model.dart';

class FoodRecognitionRepository {
  final GeminiService _geminiService;

  FoodRecognitionRepository({GeminiService? geminiService})
      : _geminiService = geminiService ?? GeminiService.instance;

  Future<FoodRecognitionModel> recognizeMeal(String imagePath) {
    return _geminiService.recognizeFood(imagePath);
  }
}
