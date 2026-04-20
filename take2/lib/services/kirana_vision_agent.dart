import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path_provider/path_provider.dart';

import '../models/kirana_detection.dart';

class KiranaVisionAgent {
  static const _spriteLabel = 'Sprite bottle';
  static const _laysLabel = 'Lays packet';
  static const List<String> _preferredModelAssetPaths = [
    'assets/ml/model_quant.tflite',
  ];
  static const _labelsAssetPath = 'assets/ml/labels.txt';

  static const List<String> _spriteKeywords = [
    'sprite',
    'soft drink',
    'soda',
    'bottle',
  ];

  static const List<String> _laysKeywords = [
    'lays',
    "lay's",
    'chips',
    'snack',
    'packet',
  ];

  ImageLabeler? _cachedLabeler;
  bool _customModelInitAttempted = false;
  bool _usingCustomModel = false;
  List<String> _labelHints = const [];

  Future<List<KiranaDetection>> analyzeImage({
    required String imagePath,
    required List<String> inventoryNames,
  }) async {
    var labeler = await _getOrCreateLabeler();

    try {
      return _detectFromLabeler(
        labeler: labeler,
        imagePath: imagePath,
        inventoryNames: inventoryNames,
      );
    } catch (_) {
      if (_usingCustomModel) {
        labeler = await _switchToOnDeviceLabeler();
        try {
          return _detectFromLabeler(
            labeler: labeler,
            imagePath: imagePath,
            inventoryNames: inventoryNames,
          );
        } catch (_) {
          return [];
        }
      }
      return [];
    }
  }

  Future<List<KiranaDetection>> _detectFromLabeler({
    required ImageLabeler labeler,
    required String imagePath,
    required List<String> inventoryNames,
  }) async {
    final labels = await labeler.processImage(InputImage.fromFilePath(imagePath));
    if (labels.isEmpty) return [];

    final detectionsByLabel = <String, KiranaDetection>{};

    for (final label in labels) {
      final rawLabel = label.label.trim();
      if (rawLabel.isEmpty) continue;

      final mappedInventoryLabel = _findBestInventoryMatch(
        candidate: rawLabel,
        inventoryNames: inventoryNames,
      );

      if (mappedInventoryLabel == null) continue;

      final confidence = label.confidence.clamp(0.0, 0.99).toDouble();
      final existing = detectionsByLabel[mappedInventoryLabel];

      if (existing == null || confidence > existing.confidence) {
        detectionsByLabel[mappedInventoryLabel] = KiranaDetection(
          label: mappedInventoryLabel,
          confidence: confidence,
          suggestedQuantity: 1,
        );
      }
    }

    if (detectionsByLabel.isEmpty) {
      final fallback = _fallbackKeywordDetections(labels, inventoryNames)
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
      return fallback;
    }

    final detections = detectionsByLabel.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return detections;
  }

  Future<ImageLabeler> _getOrCreateLabeler() async {
    if (_cachedLabeler != null) return _cachedLabeler!;

    if (!_customModelInitAttempted) {
      _customModelInitAttempted = true;

      final modelPath = await _resolveCustomModelPath();
      if (modelPath != null) {
        _labelHints = await _tryLoadLabelHints();
        _cachedLabeler = ImageLabeler(
          options: LocalLabelerOptions(
            modelPath: modelPath,
            confidenceThreshold: 0.5,
            maxCount: 10,
          ),
        );
        _usingCustomModel = true;
        return _cachedLabeler!;
      }
    }

    _cachedLabeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.6),
    );
    _usingCustomModel = false;
    return _cachedLabeler!;
  }

  Future<String?> _resolveCustomModelPath() async {
    for (final modelAssetPath in _preferredModelAssetPaths) {
      final modelPath = await _copyAssetToLocalPath(modelAssetPath);
      if (modelPath != null) return modelPath;
    }
    return null;
  }

  Future<ImageLabeler> _switchToOnDeviceLabeler() async {
    await _cachedLabeler?.close();
    _cachedLabeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.6),
    );
    _usingCustomModel = false;
    _labelHints = const [];
    return _cachedLabeler!;
  }

  Future<String?> _copyAssetToLocalPath(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final dir = await getApplicationSupportDirectory();
      final fileName = assetPath.split('/').last;
      final targetPath = '${dir.path}/$fileName';
      final file = File(targetPath);

      if (!await file.exists()) {
        final bytes = data.buffer.asUint8List();
        await file.writeAsBytes(bytes, flush: true);
      }

      return targetPath;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _tryLoadLabelHints() async {
    try {
      final raw = await rootBundle.loadString(_labelsAssetPath);
      return raw
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim().toLowerCase())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String? _findBestInventoryMatch({
    required String candidate,
    required List<String> inventoryNames,
  }) {
    final normalizedCandidate = candidate.toLowerCase().trim();
    if (normalizedCandidate.isEmpty) return null;

    final allowedByHints = _labelHints.isEmpty ||
        _labelHints.any(
          (hint) => normalizedCandidate == hint || normalizedCandidate.contains(hint),
        );

    if (!allowedByHints) return null;

    String? best;
    var bestScore = 0;

    final candidateTokens = _tokenize(normalizedCandidate);

    for (final rawInventoryName in inventoryNames) {
      final inventoryName = rawInventoryName.toLowerCase().trim();
      if (inventoryName.isEmpty) continue;

      if (inventoryName == normalizedCandidate ||
          inventoryName.contains(normalizedCandidate) ||
          normalizedCandidate.contains(inventoryName)) {
        return rawInventoryName;
      }

      final inventoryTokens = _tokenize(inventoryName);
      var score = 0;

      for (final token in candidateTokens) {
        if (inventoryTokens.contains(token) || inventoryName.contains(token)) {
          score++;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = rawInventoryName;
      }
    }

    return bestScore > 0 ? best : null;
  }

  List<String> _tokenize(String value) {
    return value
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 3)
        .toList(growable: false);
  }

  List<KiranaDetection> _fallbackKeywordDetections(
    List<ImageLabel> labels,
    List<String> inventoryNames,
  ) {
    final canReturnSprite = _hasInventoryMatch(inventoryNames, _spriteLabel);
    final canReturnLays = _hasInventoryMatch(inventoryNames, _laysLabel);

    double spriteConfidence = 0;
    double laysConfidence = 0;

    for (final label in labels) {
      final normalized = label.label.toLowerCase().trim();

      if (canReturnSprite && _containsKeyword(normalized, _spriteKeywords)) {
        if (label.confidence > spriteConfidence) {
          spriteConfidence = label.confidence;
        }
      }

      if (canReturnLays && _containsKeyword(normalized, _laysKeywords)) {
        if (label.confidence > laysConfidence) {
          laysConfidence = label.confidence;
        }
      }
    }

    final detections = <KiranaDetection>[];

    if (spriteConfidence > 0) {
      detections.add(
        KiranaDetection(
          label: _spriteLabel,
          confidence: spriteConfidence.clamp(0.0, 0.99).toDouble(),
          suggestedQuantity: 1,
        ),
      );
    }

    if (laysConfidence > 0) {
      detections.add(
        KiranaDetection(
          label: _laysLabel,
          confidence: laysConfidence.clamp(0.0, 0.99).toDouble(),
          suggestedQuantity: 1,
        ),
      );
    }

    return detections;
  }

  bool _hasInventoryMatch(List<String> inventoryNames, String target) {
    final normalizedTarget = target.toLowerCase();
    return inventoryNames.any((item) => item.toLowerCase().contains(normalizedTarget.split(' ').first));
  }

  bool _containsKeyword(String value, List<String> keywords) {
    for (final keyword in keywords) {
      if (value.contains(keyword)) return true;
    }
    return false;
  }

  Future<void> dispose() async {
    await _cachedLabeler?.close();
    _cachedLabeler = null;
    _usingCustomModel = false;
  }
}
