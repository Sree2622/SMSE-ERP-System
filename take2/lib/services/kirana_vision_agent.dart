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

      final detections = <KiranaDetection>[];
      for (final inventoryItem in inventoryNames) {
        final normalizedItem = inventoryItem.toLowerCase().trim();
        if (normalizedItem.isEmpty) continue;

        if (textBlob.contains(normalizedItem)) {
          detections.add(
            KiranaDetection(label: inventoryItem, confidence: 0.9, suggestedQuantity: 1),
          );
          continue;
        }

        final parts = normalizedItem
            .split(RegExp(r'[^a-z0-9]+'))
            .where((part) => part.length >= 4)
            .toList();
        final hasTokenMatch = parts.any(textBlob.contains);
        if (hasTokenMatch) {
          detections.add(
            KiranaDetection(label: inventoryItem, confidence: 0.72, suggestedQuantity: 1),
          );
        }

        if (detections.length >= 5) break;
      }

      return detections;
    } catch (_) {
      return [];
    } finally {
      recognizer.close();
    }
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
