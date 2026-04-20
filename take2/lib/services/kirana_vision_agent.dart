import 'dart:convert';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

import '../models/kirana_detection.dart';

class KiranaVisionAgent {
  KiranaVisionAgent({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _endpoint = String.fromEnvironment('KIRANA_LLM_ENDPOINT');
  static const List<String> _knownKiranaItems = [
    'atta',
    'basmati rice',
    'toor dal',
    'moong dal',
    'masoor dal',
    'chana dal',
    'poha',
    'rava',
    'sugar',
    'jaggery',
    'turmeric powder',
    'red chilli powder',
    'coriander powder',
    'garam masala',
    'cumin seeds',
    'mustard seeds',
    'tea',
    'coffee',
    'ghee',
    'mustard oil',
    'sunflower oil',
    'salt',
    'besan',
    'paneer',
    'soap bar',
    'detergent powder',
  ];

  Future<List<KiranaDetection>> analyzeImage({
    required String imagePath,
    required List<String> inventoryNames,
  }) async {
    if (_endpoint.isNotEmpty) {
      final cloudDetections = await _analyzeUsingEndpoint(imagePath, inventoryNames);
      if (cloudDetections.isNotEmpty) return cloudDetections;
    }

    final localDetections = await _analyzeOnDevice(imagePath, inventoryNames);
    if (localDetections.isNotEmpty) return localDetections;

    return _fallbackInventoryDetections(inventoryNames);
  }

  Future<List<KiranaDetection>> _analyzeUsingEndpoint(
    String imagePath,
    List<String> inventoryNames,
  ) async {
    final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
      ..fields['prompt'] =
          'Identify visible Indian kirana items. Return JSON as {"detections":[{"label":"...","confidence":0.0-1.0,"quantity":1}]}'
      ..fields['inventory'] = jsonEncode(inventoryNames)
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));

    final streamed = await _client.send(request).timeout(const Duration(seconds: 10));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) return [];

    final decoded = jsonDecode(response.body);
    final detectionsRaw = (decoded is Map<String, dynamic> ? decoded['detections'] : null) as List<dynamic>?;
    if (detectionsRaw == null) return [];

    return detectionsRaw
        .whereType<Map<String, dynamic>>()
        .map(KiranaDetection.fromJson)
        .where((item) => item.label.isNotEmpty)
        .toList();
  }

  Future<List<KiranaDetection>> _analyzeOnDevice(
    String imagePath,
    List<String> inventoryNames,
  ) async {
    if (inventoryNames.isEmpty) return [];

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await recognizer.processImage(InputImage.fromFilePath(imagePath));
      final textBlob = recognizedText.text.toLowerCase();
      if (textBlob.trim().isEmpty) return [];

      final normalizedBlob = _normalizeForContains(textBlob);
      final lineCandidates = <String>{
        for (final block in recognizedText.blocks)
          for (final line in block.lines) _normalizeForContains(line.text),
      }..removeWhere((line) => line.isEmpty);
      final ocrTokens = _tokenize(textBlob).toSet();

      final scoredDetections = <KiranaDetection>[];
      for (final inventoryItem in inventoryNames) {
        final confidence = _scoreInventoryMatch(
          inventoryItem,
          rawBlob: textBlob,
          normalizedBlob: normalizedBlob,
          lineCandidates: lineCandidates,
          ocrTokens: ocrTokens,
        );
        if (confidence < 0.6) continue;

        scoredDetections.add(
          KiranaDetection(label: inventoryItem, confidence: confidence, suggestedQuantity: 1),
        );
      }

      scoredDetections.sort((a, b) => b.confidence.compareTo(a.confidence));
      return scoredDetections.take(5).toList();
    } catch (_) {
      return [];
    } finally {
      recognizer.close();
    }
  }

  double _scoreInventoryMatch(
    String inventoryItem, {
    required String rawBlob,
    required String normalizedBlob,
    required Set<String> lineCandidates,
    required Set<String> ocrTokens,
  }) {
    final normalizedItem = inventoryItem.toLowerCase().trim();
    if (normalizedItem.isEmpty) return 0;

    final normalizedInventory = _normalizeForContains(normalizedItem);
    if (normalizedInventory.isEmpty) return 0;

    if (rawBlob.contains(normalizedItem)) return 0.97;
    if (normalizedBlob.contains(normalizedInventory)) return 0.93;
    if (lineCandidates.any((line) => line.contains(normalizedInventory))) return 0.9;

    final inventoryTokens = _tokenize(normalizedItem);
    if (inventoryTokens.isEmpty) return 0;

    final matchedTokens = inventoryTokens.where(ocrTokens.contains).length;
    if (matchedTokens == 0) {
      final primaryToken = inventoryTokens.first;
      if (primaryToken.length >= 4 && normalizedBlob.contains(primaryToken)) return 0.64;
      return 0;
    }

    final coverage = matchedTokens / inventoryTokens.length;
    if (coverage >= 1) return 0.88;
    if (coverage >= 0.67) return 0.78;
    if (coverage >= 0.5) return 0.69;
    return 0.62;
  }

  String _normalizeForContains(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  List<String> _tokenize(String input) {
    return input
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 3)
        .toList();
  }

  List<KiranaDetection> _fallbackInventoryDetections(List<String> inventoryNames) {
    final matches = <KiranaDetection>[];

    for (final item in inventoryNames) {
      final normalized = item.toLowerCase();
      final known = _knownKiranaItems.where((seed) => normalized.contains(seed)).toList();
      if (known.isNotEmpty) {
        matches.add(
          KiranaDetection(label: item, confidence: 0.55, suggestedQuantity: 1),
        );
      }
      if (matches.length >= 5) break;
    }

    return matches;
  }
}
