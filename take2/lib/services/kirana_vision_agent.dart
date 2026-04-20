import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/kirana_detection.dart';

class KiranaVisionAgent {
  KiranaVisionAgent({
    http.Client? client,
    String localModelPath = _defaultLocalModelPath,
  })  : _client = client ?? http.Client(),
        _localModelPath = localModelPath;

  static const String _defaultLocalModelPath = String.fromEnvironment(
    'KIRANA_TFLITE_MODEL_PATH',
    defaultValue: 'assets/ml/kirana_brands.tflite',
  );

  final http.Client _client;
  final String _localModelPath;

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
    'sprite',
  ];

  Future<List<KiranaDetection>> analyzeImage({
    required String imagePath,
    required List<String> inventoryNames,
  }) async {
    final localModelDetections = await _analyzeUsingLocalModel(imagePath, inventoryNames);
    if (localModelDetections.isNotEmpty) return localModelDetections;

    final baseModelDetections = await _analyzeUsingBaseLabeler(imagePath, inventoryNames);
    if (baseModelDetections.isNotEmpty) return baseModelDetections;

    if (_endpoint.isNotEmpty) {
      final cloudDetections = await _analyzeUsingEndpoint(imagePath, inventoryNames);
      if (cloudDetections.isNotEmpty) return cloudDetections;
    }

    final ocrDetections = await _analyzeOnDevice(imagePath, inventoryNames);
    if (ocrDetections.isNotEmpty) return ocrDetections;

    return _fallbackInventoryDetections(inventoryNames);
  }


  Future<List<KiranaDetection>> _analyzeUsingLocalModel(
    String imagePath,
    List<String> inventoryNames,
  ) async {
    if (inventoryNames.isEmpty || _localModelPath.trim().isEmpty) return [];

    final resolvedModelPath = await _resolveModelPath(_localModelPath);
    if (resolvedModelPath == null) return [];

    final options = LocalLabelerOptions(
      modelPath: resolvedModelPath,
      confidenceThreshold: 0.55,
      maxCount: 6,
    );

    final labeler = ImageLabeler(options: options);

    try {
      final labels = await labeler.processImage(InputImage.fromFilePath(imagePath));
      if (labels.isEmpty) return [];

      final detections = <KiranaDetection>[];
      final seen = <String>{};

      for (final label in labels) {
        final inventoryMatch = _matchLabelToInventory(label.label, inventoryNames);
        if (inventoryMatch == null) continue;

        final normalized = inventoryMatch.toLowerCase();
        if (!seen.add(normalized)) continue;

        detections.add(
          KiranaDetection(
            label: inventoryMatch,
            confidence: label.confidence.clamp(0.0, 0.99).toDouble(),
            suggestedQuantity: 1,
          ),
        );
      }

      detections.sort((a, b) => b.confidence.compareTo(a.confidence));
      return detections;
    } catch (_) {
      return [];
    } finally {
      labeler.close();
    }
  }

  String? _matchLabelToInventory(String modelLabel, List<String> inventoryNames) {
    final normalizedLabel = modelLabel.toLowerCase().trim();
    if (normalizedLabel.isEmpty) return null;

    String? bestMatch;
    double bestScore = 0;

    for (final inventoryItem in inventoryNames) {
      final normalizedItem = inventoryItem.toLowerCase().trim();
      if (normalizedItem.isEmpty) continue;

      if (normalizedItem == normalizedLabel ||
          normalizedItem.contains(normalizedLabel) ||
          normalizedLabel.contains(normalizedItem)) {
        return inventoryItem;
      }

      final parts = normalizedItem
          .split(RegExp(r'[^a-z0-9]+'))
          .where((part) => part.length >= 3)
          .toList();
      if (parts.isEmpty) continue;

      final tokenHits = parts.where(normalizedLabel.contains).length;
      if (tokenHits > 0) {
        final score = tokenHits / parts.length;
        if (score > bestScore) {
          bestScore = score;
          bestMatch = inventoryItem;
        }
      }

      final closeMatch = parts.any(
        (part) => _levenshteinDistance(part, normalizedLabel) <= 2,
      );
      if (closeMatch && bestScore < 0.65) {
        bestScore = 0.65;
        bestMatch = inventoryItem;
      }
    }

    return bestScore >= 0.55 ? bestMatch : null;
  }



  Future<String?> _resolveModelPath(String configuredPath) async {
    final trimmed = configuredPath.trim();
    if (trimmed.isEmpty) return null;

    final directFile = File(trimmed);
    if (await directFile.exists()) return directFile.path;

    if (!trimmed.startsWith('assets/')) return null;

    try {
      final modelData = await rootBundle.load(trimmed);
      final tempDir = await getTemporaryDirectory();
      final modelFile = File(
        '${tempDir.path}/${trimmed.split('/').last}',
      );

      if (!await modelFile.exists()) {
        await modelFile.writeAsBytes(
          modelData.buffer.asUint8List(),
          flush: true,
        );
      }

      return modelFile.path;
    } catch (_) {
      return null;
    }
  }

  Future<List<KiranaDetection>> _analyzeUsingBaseLabeler(
    String imagePath,
    List<String> inventoryNames,
  ) async {
    if (inventoryNames.isEmpty) return [];

    final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.6));

    try {
      final labels = await labeler.processImage(InputImage.fromFilePath(imagePath));
      if (labels.isEmpty) return [];

      final detections = <KiranaDetection>[];
      final seen = <String>{};

      for (final label in labels) {
        final inventoryMatch = _matchLabelToInventory(label.label, inventoryNames);
        if (inventoryMatch == null) continue;

        final normalized = inventoryMatch.toLowerCase();
        if (!seen.add(normalized)) continue;

        detections.add(
          KiranaDetection(
            label: inventoryMatch,
            confidence: (label.confidence * 0.85).clamp(0.0, 0.9).toDouble(),
            suggestedQuantity: 1,
          ),
        );
      }

      detections.sort((a, b) => b.confidence.compareTo(a.confidence));
      return detections;
    } catch (_) {
      return [];
    } finally {
      labeler.close();
    }
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
      final textTokens = textBlob
          .split(RegExp(r'[^a-z0-9]+'))
          .where((token) => token.length >= 4)
          .toList();

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
          continue;
        }

        final hasCloseTokenMatch = parts.any(
          (part) => textTokens.any(
            (textToken) => _levenshteinDistance(part, textToken) <= 1,
          ),
        );
        if (hasCloseTokenMatch) {
          detections.add(
            KiranaDetection(label: inventoryItem, confidence: 0.64, suggestedQuantity: 1),
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

  int _levenshteinDistance(String source, String target) {
    if (source == target) return 0;
    if (source.isEmpty) return target.length;
    if (target.isEmpty) return source.length;

    var previous = List<int>.generate(target.length + 1, (index) => index);
    for (var i = 0; i < source.length; i++) {
      final current = List<int>.filled(target.length + 1, 0);
      current[0] = i + 1;

      for (var j = 0; j < target.length; j++) {
        final substitutionCost = source[i] == target[j] ? 0 : 1;
        current[j + 1] = [
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + substitutionCost,
        ].reduce((a, b) => a < b ? a : b);
      }

      previous = current;
    }

    return previous[target.length];
  }
}
