import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fast_flow/features/food/data/models/food_recognition_model.dart';

class GeminiApiException implements Exception {
  final String message;
  final int? statusCode;
  GeminiApiException(this.message, {this.statusCode});
  @override
  String toString() => 'GeminiApiException: $message (status: $statusCode)';
}

class GeminiApiKeyMissingException implements Exception {
  @override
  String toString() => 'GeminiApiKeyMissingException: Gemini API key is missing. Please add it to your .env file.';
}

class GeminiService {
  static final GeminiService instance = GeminiService._();
  final http.Client _client;

  GeminiService._({http.Client? client}) : _client = client ?? http.Client();

  factory GeminiService.test(http.Client client) => GeminiService._(client: client);

  Future<FoodRecognitionModel> recognizeFood(String imagePath) async {
    String? apiKey;
    try {
      apiKey = dotenv.env['GEMINI_API_KEY'];
    } catch (_) {}

    if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_KEY') {
      throw GeminiApiKeyMissingException();
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      throw const FileSystemException('Image file not found');
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

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

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
    } on SocketException {
      throw GeminiApiException('No internet connection. Please check your network and try again.');
    } on http.ClientException catch (e) {
      throw GeminiApiException('HTTP request failed: ${e.message}');
    }
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
