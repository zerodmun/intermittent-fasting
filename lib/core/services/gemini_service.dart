import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fast_flow/features/food/data/models/food_recognition_model.dart';
import 'package:fast_flow/core/services/logger_service.dart';

enum AIExceptionType {
  quotaExceeded,
  networkError,
  timeout,
  invalidApiKey,
  invalidResponse,
  imageTooLarge,
  cancelled,
  serverError,
  unknown,
}

class AIException implements Exception {
  final AIExceptionType type;
  final String message;
  final int? statusCode;

  const AIException({
    required this.type,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => 'AIException: [$type] $message (status: $statusCode)';
}

class GeminiApiKeyMissingException extends AIException {
  GeminiApiKeyMissingException()
      : super(
          type: AIExceptionType.invalidApiKey,
          message: 'Gemini API key is missing. Please add it to your .env file.',
        );
}

class GeminiApiException extends AIException {
  GeminiApiException(String message, {super.statusCode})
      : super(
          type: _mapStatusCode(statusCode),
          message: message,
        );

  static AIExceptionType _mapStatusCode(int? code) {
    if (code == null) return AIExceptionType.unknown;
    if (code == 400) return AIExceptionType.unknown;
    if (code == 401 || code == 403) return AIExceptionType.invalidApiKey;
    if (code == 404) return AIExceptionType.serverError;
    if (code == 408) return AIExceptionType.timeout;
    if (code == 429) return AIExceptionType.quotaExceeded;
    if (code == 500 || code == 503) return AIExceptionType.serverError;
    return AIExceptionType.unknown;
  }
}

class GeminiService {
  static final GeminiService instance = GeminiService._();
  final http.Client _client;
  
  // 11. Cache Result: Reuse previous result if same image path has been analyzed
  final Map<String, FoodRecognitionModel> _cache = {};

  GeminiService._({http.Client? client}) : _client = client ?? http.Client();

  factory GeminiService.test(http.Client client) => GeminiService._(client: client);

  Future<FoodRecognitionModel> recognizeFood(String imagePath) async {
    if (_cache.containsKey(imagePath)) {
      LoggerService.i('[GeminiService] Reusing cached result for $imagePath');
      return _cache[imagePath]!;
    }
    final result = await _recognizeFoodWithRetry(imagePath, isRetry: false);
    _cache[imagePath] = result;
    return result;
  }

  Future<FoodRecognitionModel> _recognizeFoodWithRetry(String imagePath, {required bool isRetry}) async {
    try {
      // 10. Image Validation before upload: check existence, readability, size (< 10 MB)
      final file = File(imagePath);
      if (!await file.exists()) {
        throw const AIException(
          type: AIExceptionType.unknown,
          message: 'Image file does not exist.',
        );
      }

      final size = await file.length();
      if (size > 10 * 1024 * 1024) {
        throw const AIException(
          type: AIExceptionType.imageTooLarge,
          message: 'Image size exceeds the 10 MB limit.',
        );
      }

      String? apiKey;
      try {
        apiKey = dotenv.env['GEMINI_API_KEY'];
      } catch (_) {}

      if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_KEY') {
        throw GeminiApiKeyMissingException();
      }

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$apiKey',
      );

      const prompt = 'Analyze the food in this image. Estimate its name, estimated weight (in grams), macronutrients (calories, protein in grams, fat in grams, carbs in grams), and a confidence score between 0.0 and 1.0 based on how clear and identifiable the food is. '
          'Return ONLY a JSON object in this format:\n'
          '{\n'
          '  "name": "...",\n'
          '  "estimated_weight_g": 0,\n'
          '  "calories": 0,\n'
          '  "protein": 0,\n'
          '  "fat": 0,\n'
          '  "carbs": 0,\n'
          '  "confidence": 0.0\n'
          '}';

      final body = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inlineData': {
                  'mimeType': 'image/jpeg',
                  'data': base64Image,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
        }
      };

      // 3. Status codes and 7. timeout check
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw GeminiApiException(
          'API returned status code ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode,
        );
      }

      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = responseJson['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw GeminiApiException('No completion candidates found in Gemini response.');
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw GeminiApiException('No content parts found in candidate.');
      }

      final rawText = parts[0]['text'] as String?;
      if (rawText == null || rawText.isEmpty) {
        throw GeminiApiException('Empty text returned from Gemini.');
      }

      try {
        final extractedJson = _extractJson(rawText);
        return FoodRecognitionModel.fromJson(extractedJson);
      } catch (e) {
        throw GeminiApiException('Failed to parse Gemini response text into structured JSON: $e. Raw response: $rawText');
      }
    } catch (e) {
      final shouldRetry = !isRetry && _isRetryable(e);
      if (shouldRetry) {
        LoggerService.w('[GeminiService] Transient error encountered. Retrying in 1s...');
        await Future.delayed(const Duration(seconds: 1));
        return _recognizeFoodWithRetry(imagePath, isRetry: true);
      }

      if (e is AIException) {
        rethrow;
      } else if (e is SocketException) {
        throw const AIException(
          type: AIExceptionType.networkError,
          message: 'No Internet Connection',
        );
      } else if (e is TimeoutException) {
        throw const AIException(
          type: AIExceptionType.timeout,
          message: 'Connection Timeout',
        );
      } else {
        throw AIException(
          type: AIExceptionType.unknown,
          message: e.toString(),
        );
      }
    }
  }

  bool _isRetryable(Object e) {
    if (e is GeminiApiException) {
      final code = e.statusCode;
      return code == 500 || code == 503 || code == 408;
    }
    if (e is SocketException || e is TimeoutException) {
      return true;
    }
    return false;
  }

  Map<String, dynamic> _extractJson(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      final startIndex = cleaned.indexOf('{');
      final endIndex = cleaned.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1) {
        cleaned = cleaned.substring(startIndex, endIndex + 1);
      }
    }
    return jsonDecode(cleaned) as Map<String, dynamic>;
  }
}
