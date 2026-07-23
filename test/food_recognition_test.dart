import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fast_flow/features/food/data/models/food_recognition_model.dart';
import 'package:fast_flow/core/services/gemini_service.dart';

void main() {
  group('FoodRecognitionModel Tests', () {
    test('fromJson parses correct JSON structure', () {
      final json = {
        'name': 'Avocado Toast',
        'estimated_weight_g': 250,
        'calories': 350,
        'protein': 12,
        'fat': 20,
        'carbs': 35,
        'confidence': 0.85,
      };

      final model = FoodRecognitionModel.fromJson(json);

      expect(model.name, equals('Avocado Toast'));
      expect(model.estimatedWeightG, equals(250));
      expect(model.calories, equals(350));
      expect(model.protein, equals(12));
      expect(model.fat, equals(20));
      expect(model.carbs, equals(35));
      expect(model.confidence, equals(0.85));
    });

    test('fromJson handles null values with safe fallbacks', () {
      final json = <String, dynamic>{};
      final model = FoodRecognitionModel.fromJson(json);

      expect(model.name, equals('Unknown Food'));
      expect(model.estimatedWeightG, equals(0));
      expect(model.calories, equals(0));
      expect(model.protein, equals(0));
      expect(model.fat, equals(0));
      expect(model.carbs, equals(0));
      expect(model.confidence, equals(1.0));
    });
  });

  group('GeminiService Tests', () {
    late File tempFile;

    setUpAll(() async {
      final tempDir = Directory.systemTemp;
      tempFile = File('${tempDir.path}/test_image.jpg');
      await tempFile.writeAsBytes([1, 2, 3, 4]);
    });

    tearDownAll(() async {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    });

    test('recognizeFood throws GeminiApiKeyMissingException when key is missing', () {
      dotenv.clean();
      final mockClient = MockClient((request) async => http.Response('{}', 200));
      final service = GeminiService.test(mockClient);

      expect(
        () => service.recognizeFood(tempFile.path),
        throwsA(isA<GeminiApiKeyMissingException>()),
      );
    });

    test('recognizeFood parses clean JSON from Gemini response successfully', () async {
      dotenv.testLoad(fileInput: 'GEMINI_API_KEY=test_key');
      
      final mockResponse = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': '{\n'
                      '  "name": "Apple",\n'
                      '  "estimated_weight_g": 150,\n'
                      '  "calories": 52,\n'
                      '  "protein": 1,\n'
                      '  "fat": 0,\n'
                      '  "carbs": 14,\n'
                      '  "confidence": 0.95\n'
                      '}'
                }
              ]
            }
          }
        ]
      };

      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['key'], equals('test_key'));
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final service = GeminiService.test(mockClient);
      final result = await service.recognizeFood(tempFile.path);

      expect(result.name, equals('Apple'));
      expect(result.estimatedWeightG, equals(150));
      expect(result.calories, equals(52));
    });

    test('recognizeFood extracts JSON even when wrapped in markdown backticks', () async {
      dotenv.testLoad(fileInput: 'GEMINI_API_KEY=test_key');

      final mockResponse = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': '```json\n'
                      '{\n'
                      '  "name": "Banana",\n'
                      '  "estimated_weight_g": 120,\n'
                      '  "calories": 89,\n'
                      '  "protein": 1,\n'
                      '  "fat": 0,\n'
                      '  "carbs": 23,\n'
                      '  "confidence": 0.88\n'
                      '}\n'
                      '```'
                }
              ]
            }
          }
        ]
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final service = GeminiService.test(mockClient);
      final result = await service.recognizeFood(tempFile.path);

      expect(result.name, equals('Banana'));
      expect(result.estimatedWeightG, equals(120));
      expect(result.calories, equals(89));
    });

    test('recognizeFood throws GeminiApiException on non-200 HTTP status', () async {
      dotenv.testLoad(fileInput: 'GEMINI_API_KEY=test_key');

      final mockClient = MockClient((request) async {
        return http.Response('Quota exceeded', 429);
      });

      final service = GeminiService.test(mockClient);

      expect(
        () => service.recognizeFood(tempFile.path),
        throwsA(isA<GeminiApiException>()),
      );
    });

    test('recognizeFood throws GeminiApiException when no candidates returned', () async {
      dotenv.testLoad(fileInput: 'GEMINI_API_KEY=test_key');

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'candidates': []}), 200);
      });

      final service = GeminiService.test(mockClient);

      expect(
        () => service.recognizeFood(tempFile.path),
        throwsA(isA<GeminiApiException>()),
      );
    });
  });
}
