import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../../core/data/services/hive_service.dart';

class OfflineException implements Exception {
  final String message;
  const OfflineException([this.message = 'No internet connection.']);
  @override
  String toString() => message;
}

class FoodProduct {
  final String? barcode;
  final String name;
  final String brand;
  final String? imageUrl;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final String servingSize;
  final double fiber;

  const FoodProduct({
    this.barcode,
    required this.name,
    required this.brand,
    this.imageUrl,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.servingSize,
    this.fiber = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'name': name,
      'brand': brand,
      'imageUrl': imageUrl,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fat': fat,
      'servingSize': servingSize,
      'fiber': fiber,
    };
  }

  factory FoodProduct.fromMap(Map<String, dynamic> map) {
    return FoodProduct(
      barcode: map['barcode'] as String?,
      name: map['name'] as String? ?? 'Unknown Food',
      brand: map['brand'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carbohydrates: (map['carbohydrates'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
      servingSize: map['servingSize'] as String? ?? '100g',
      fiber: (map['fiber'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FoodSearchService {
  static const String _userAgent = 'FomoIF - Android - Version 1.0 - https://fomoif.example.com';

  static const Map<String, String> _idToEn = {
    'nasi': 'rice',
    'nasi putih': 'white rice',
    'nasi goreng': 'fried rice',
    'ayam': 'chicken',
    'sapi': 'beef',
    'telur': 'egg',
    'ikan': 'fish',
    'susu': 'milk',
    'roti': 'bread',
    'mie': 'noodle',
    'mie instan': 'instant noodle',
    'pisang': 'banana',
    'apel': 'apple',
    'jeruk': 'orange',
    'semangka': 'watermelon',
    'kentang': 'potato',
    'tahu': 'tofu',
    'tempe': 'tempeh',
    'kopi': 'coffee',
    'teh': 'tea',
    'gula': 'sugar',
    'garam': 'salt',
  };

  static const Map<String, String> _enToId = {
    'rice': 'nasi',
    'white rice': 'nasi putih',
    'fried rice': 'nasi goreng',
    'chicken': 'ayam',
    'beef': 'sapi',
    'egg': 'telur',
    'fish': 'ikan',
    'milk': 'susu',
    'bread': 'roti',
    'noodle': 'mie',
    'instant noodle': 'mie instan',
    'banana': 'pisang',
    'apple': 'apel',
    'orange': 'jeruk',
    'watermelon': 'semangka',
    'potato': 'kentang',
    'tofu': 'tahu',
    'tempeh': 'tempe',
    'coffee': 'kopi',
    'tea': 'teh',
    'sugar': 'gula',
    'salt': 'garam',
  };

  static String _normalize(String input) {
    var str = input.toLowerCase().trim();
    // Accents stripping
    str = str.replaceAll(RegExp(r'[áàâäãå]'), 'a');
    str = str.replaceAll(RegExp(r'[éèêë]'), 'e');
    str = str.replaceAll(RegExp(r'[íìîï]'), 'i');
    str = str.replaceAll(RegExp(r'[óòôöõ]'), 'o');
    str = str.replaceAll(RegExp(r'[úùûü]'), 'u');
    str = str.replaceAll(RegExp(r'[ç]'), 'c');
    str = str.replaceAll(RegExp(r'[ñ]'), 'n');
    // Remove special characters keeping only letters, numbers, and space
    str = str.replaceAll(RegExp(r'[^a-z0-9 ]'), '');
    return str;
  }

  static String? _translateQueryToEnglish(String query) {
    final norm = _normalize(query);
    if (_idToEn.containsKey(norm)) return _idToEn[norm];

    final words = norm.split(' ');
    bool translatedAny = false;
    final translatedWords = words.map((w) {
      if (_idToEn.containsKey(w)) {
        translatedAny = true;
        return _idToEn[w]!;
      }
      return w;
    }).toList();

    if (translatedAny) {
      return translatedWords.join(' ');
    }
    return null;
  }

  static String _translateFoodNameToEnglish(String name) {
    var translatedName = name;
    
    // Sort phrases by descending length to match longest phrase first
    final sortedPhrases = _idToEn.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final phrase in sortedPhrases) {
      final replacement = _idToEn[phrase]!;
      final regex = RegExp(r'\b' + RegExp.escape(phrase) + r'\b', caseSensitive: false);
      translatedName = translatedName.replaceAllMapped(regex, (match) {
        final matchedText = match.group(0)!;
        if (matchedText.startsWith(RegExp(r'[A-Z]'))) {
          return replacement[0].toUpperCase() + replacement.substring(1);
        }
        return replacement;
      });
    }

    return translatedName;
  }

  static String _cleanFoodName(String rawName, String brand) {
    var name = rawName.trim();
    if (name.isEmpty) return 'Unknown Food';

    // 1. Remove brand name if present in the food name
    if (brand.isNotEmpty) {
      final escapedBrand = RegExp.escape(brand.trim());
      final brandRegex = RegExp(r'\b' + escapedBrand + r'\b', caseSensitive: false);
      name = name.replaceAll(brandRegex, '');
    }

    // 2. Remove packaging details, weight markers, volume indicators
    // e.g. 1kg, 100g, 500ml, 1 kg, 250 g, pack of 4, 300ml, 1.5l, etc.
    final weightRegex = RegExp(r'\b\d+(\.\d+)?\s*(g|kg|ml|l|oz|pcs|pack|bags|sachet|gr|ct)\b', caseSensitive: false);
    name = name.replaceAll(weightRegex, '');

    // Remove empty parenthesis/brackets
    name = name.replaceAll(RegExp(r'\(\s*\)'), '');
    name = name.replaceAll(RegExp(r'\[\s*\]'), '');

    // 3. Remove other common supermarket catalog noise
    name = name.replaceAll(RegExp(r'\b\d+\b'), '');
    name = name.replaceAll(RegExp(r'\s+'), ' '); // collapse spaces
    name = name.trim();

    // Remove leading/trailing non-word characters
    name = name.replaceAll(RegExp(r'^[-:,/\s]+|[-:,/\s]+$'), '');

    if (name.isEmpty) {
      name = rawName;
    }

    // 4. Translate Indonesian dictionary words to English
    name = _translateFoodNameToEnglish(name);

    // 5. Title Case Capitalization
    return _toTitleCase(name);
  }

  static String _toTitleCase(String input) {
    if (input.isEmpty) return input;
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static double _parseNutrient(Map? nutriments, String key1, String key2, String key3) {
    if (nutriments == null) return 0.0;
    final val = nutriments[key1] ?? nutriments[key2] ?? nutriments[key3];
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  /// Search food products by name with offline support, local caching, and generic food normalization.
  static Future<List<FoodProduct>> searchByName(String query) async {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return [];

    final cacheKey = 'query_$normalized';
    final box = HiveService.instance.foodSearchCacheBox;

    // Check cache first
    if (box.containsKey(cacheKey)) {
      final cachedRaw = box.get(cacheKey) as List?;
      if (cachedRaw != null) {
        return cachedRaw.map((e) => FoodProduct.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      }
    }

    // Translate query to English before searching to ensure maximum matching quality
    final englishQuery = _translateQueryToEnglish(normalized) ?? normalized;

    List<FoodProduct> results = [];
    try {
      results = await _fetchFromApi(englishQuery);
      
      // If empty, fallback to searching with the normalized query
      if (results.isEmpty && englishQuery != normalized) {
        results = await _fetchFromApi(normalized);
      }
    } on SocketException catch (_) {
      throw const OfflineException();
    } on http.ClientException catch (_) {
      throw const OfflineException();
    } catch (e) {
      if (e is OfflineException) rethrow;
      throw Exception('Search error: $e');
    }

    final processed = _processResults(results, englishQuery);
    
    // Cache results
    await box.put(cacheKey, processed.map((e) => e.toMap()).toList());
    return processed;
  }

  static Future<List<FoodProduct>> _fetchFromApi(String query) async {
    // Try relevance-optimized V1 CGI search endpoint first
    final urlV1 = Uri.parse('https://world.openfoodfacts.org/cgi/search.pl?search_terms=${Uri.encodeComponent(query)}&search_simple=1&action=process&json=1&fields=code,product_name,product_name_en,brands,image_url,serving_size,nutriments');
    try {
      final response = await http.get(urlV1, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final products = _parseSearchResponse(decoded);
        if (products.isNotEmpty) return products;
      }
    } catch (e) {
      print('CGI V1 search error, falling back to V2: $e');
    }

    // Fallback to stable V2 search endpoint
    final urlV2 = Uri.parse('https://world.openfoodfacts.org/api/v2/search?search_terms=${Uri.encodeComponent(query)}&fields=code,product_name,product_name_en,brands,image_url,serving_size,nutriments&json=true');
    final response = await http.get(urlV2, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseSearchResponse(decoded);
    } else {
      throw Exception('Failed to load food search results from OpenFoodFacts API.');
    }
  }

  /// Search food product by barcode with offline support and local caching.
  static Future<FoodProduct?> searchByBarcode(String barcode) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return null;

    final cacheKey = 'barcode_$normalized';
    final box = HiveService.instance.foodSearchCacheBox;

    // Check cache first
    if (box.containsKey(cacheKey)) {
      final cachedRaw = box.get(cacheKey) as Map?;
      if (cachedRaw != null) {
        return FoodProduct.fromMap(Map<String, dynamic>.from(cachedRaw));
      }
    }

    // Call API
    final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$normalized.json');
    try {
      final response = await http.get(url, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final product = _parseBarcodeResponse(normalized, decoded);
        
        if (product != null) {
          // Cache results
          await box.put(cacheKey, product.toMap());
        }
        return product;
      } else {
        throw Exception('Failed to look up barcode from OpenFoodFacts API.');
      }
    } on SocketException catch (_) {
      throw const OfflineException();
    } on http.ClientException catch (_) {
      throw const OfflineException();
    } catch (e) {
      if (e is OfflineException) rethrow;
      throw Exception('Barcode error: $e');
    }
  }

  static List<FoodProduct> _parseSearchResponse(Map<String, dynamic> data) {
    final list = data['products'] as List?;
    if (list == null) return [];
    final results = <FoodProduct>[];
    
    for (final item in list) {
      try {
        final map = item as Map;
        final nutriments = map['nutriments'] as Map?;
        
        final rawName = map['product_name_en']?.toString() ?? map['product_name']?.toString() ?? 'Unknown Food';
        final brand = map['brands']?.toString() ?? '';
        final name = _cleanFoodName(rawName, brand);
        
        final imageUrl = map['image_url']?.toString();
        final servingSize = map['serving_size']?.toString() ?? '100g';

        final calories = _parseNutrient(nutriments, 'energy-kcal_100g', 'energy-kcal', 'energy-kcal_value');
        final protein = _parseNutrient(nutriments, 'proteins_100g', 'proteins', 'proteins_value');
        final carbohydrates = _parseNutrient(nutriments, 'carbohydrates_100g', 'carbohydrates', 'carbohydrates_value');
        final fat = _parseNutrient(nutriments, 'fat_100g', 'fat', 'fat_value');
        final fiber = _parseNutrient(nutriments, 'fiber_100g', 'fiber', 'fiber_value');

        results.add(FoodProduct(
          name: name,
          brand: brand,
          imageUrl: imageUrl,
          calories: calories,
          protein: protein,
          carbohydrates: carbohydrates,
          fat: fat,
          servingSize: servingSize,
          fiber: fiber,
        ));
      } catch (e) {
        print('FoodSearchService: Skipping malformed search product: $e');
      }
    }
    return results;
  }

  static FoodProduct? _parseBarcodeResponse(String barcode, Map<String, dynamic> data) {
    final status = data['status'];
    if (status != 1 && status != '1') return null;
    final productMap = data['product'] as Map?;
    if (productMap == null) return null;

    try {
      final nutriments = productMap['nutriments'] as Map?;
      
      final rawName = productMap['product_name_en']?.toString() ?? productMap['product_name']?.toString() ?? 'Unknown Food';
      final brand = productMap['brands']?.toString() ?? '';
      final name = _cleanFoodName(rawName, brand);
      
      final imageUrl = productMap['image_url']?.toString();
      final servingSize = productMap['serving_size']?.toString() ?? '100g';

      final calories = _parseNutrient(nutriments, 'energy-kcal_100g', 'energy-kcal', 'energy-kcal_value');
      final protein = _parseNutrient(nutriments, 'proteins_100g', 'proteins', 'proteins_value');
      final carbohydrates = _parseNutrient(nutriments, 'carbohydrates_100g', 'carbohydrates', 'carbohydrates_value');
      final fat = _parseNutrient(nutriments, 'fat_100g', 'fat', 'fat_value');
      final fiber = _parseNutrient(nutriments, 'fiber_100g', 'fiber', 'fiber_value');

      return FoodProduct(
        barcode: barcode,
        name: name,
        brand: brand,
        imageUrl: imageUrl,
        calories: calories,
        protein: protein,
        carbohydrates: carbohydrates,
        fat: fat,
        servingSize: servingSize,
        fiber: fiber,
      );
    } catch (e) {
      print('FoodSearchService: Error parsing barcode product: $e');
      return null;
    }
  }

  static List<FoodProduct> _processResults(List<FoodProduct> products, String query) {
    final normQuery = _normalize(query);
    if (normQuery.isEmpty) return [];

    final negativeKeywords = {
      'dog', 'cat', 'pet', 'shampoo', 'soap', 'conditioner', 'lotion',
      'detergent', 'cleaner', 'toy', 'body wash', 'hair', 'skin', 'cosmetic'
    };

    final queryWords = normQuery.split(' ');

    // 1. Filter out meaningless, noisy, or unrelated titles
    final cleanProducts = products.where((p) {
      final normName = _normalize(p.name);
      if (normName.length <= 2) return false;
      if (RegExp(r'^\d+$').hasMatch(normName)) return false;

      // Filter out negative keywords
      final nameWords = normName.split(' ');
      if (nameWords.any((w) => negativeKeywords.contains(w))) {
        return false;
      }

      // Relevance check: must contain the query words as whole words
      return queryWords.every((qw) {
        final regex = RegExp(r'\b' + RegExp.escape(qw) + r'\b');
        return regex.hasMatch(normName);
      });
    }).toList();

    // 2. Remove duplicates based on name + brand combo
    final seen = <String>{};
    final unique = <FoodProduct>[];
    for (final p in cleanProducts) {
      final key = '${p.name.toLowerCase().trim()}_${p.brand.toLowerCase().trim()}';
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(p);
      }
    }

    // 3. Ignore products with missing nutrition facts whenever possible
    final withNutrition = unique.where((p) =>
        p.calories > 0 || p.protein > 0 || p.carbohydrates > 0 || p.fat > 0).toList();
    final candidateList = withNutrition.isNotEmpty ? withNutrition : unique;

    // 4. Calculate relevance scores and sort
    final scored = candidateList.map((p) {
      final normName = _normalize(p.name);
      double score = 0.0;

      // Rule A: Exact match (highest priority)
      if (normName == normQuery) {
        score += 10000;
      }
      // Rule B: Starts with query
      else if (normName.startsWith(normQuery)) {
        score += 8000;
        score -= normName.length * 2; // minor penalty for longer names (favors simplicity)
      }
      // Rule C: Ends with query (e.g. "White Rice", "Brown Rice" for query "rice")
      else if (normName.endsWith(normQuery)) {
        score += 7000;
        score -= normName.length * 2;
      }
      // Rule D: Contains the query words
      else {
        score += 5000;
        score -= normName.length * 2;
      }

      // Rule E: Prioritize common/generic names (often brand-free)
      if (p.brand.isEmpty) {
        score += 1000;
      }

      // Rule F: Complete nutrition data bonus
      final hasComplete = p.calories > 0 && p.protein > 0 && p.carbohydrates > 0 && p.fat > 0 && p.servingSize.isNotEmpty && p.servingSize != '100g';
      if (hasComplete) {
        score += 500;
      }

      return _ScoredProduct(p, score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.map((sp) => sp.product).toList();
  }
}

class _ScoredProduct {
  final FoodProduct product;
  final double score;
  _ScoredProduct(this.product, this.score);
}
