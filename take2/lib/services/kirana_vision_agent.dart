import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../models/kirana_detection.dart';

class KiranaVisionAgent {
  static const _spriteLabel = 'Sprite bottle';
  static const _laysLabel = 'Lays packet';

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

  Future<List<KiranaDetection>> analyzeImage({
    required String imagePath,
    required List<String> inventoryNames,
  }) async {
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.6),
    );

    try {
      final labels = await labeler.processImage(InputImage.fromFilePath(imagePath));
      if (labels.isEmpty) return [];

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

      detections.sort((a, b) => b.confidence.compareTo(a.confidence));
      return detections;
    } catch (_) {
      return [];
    } finally {
      labeler.close();
    }
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
}
