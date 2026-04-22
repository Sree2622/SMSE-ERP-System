import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

import '../models/kirana_detection.dart';

class KiranaVisionAgent {
  static const _modelPath = 'assets/ml/model_unquant.tflite';
  static const _labelsPath = 'assets/ml/labels.txt';

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;

  // =========================
  // LOAD MODEL
  // =========================
  Future<void> _loadModel() async {
    if (_isLoaded) return;

    _interpreter = await Interpreter.fromAsset(_modelPath);

    final labelData = await rootBundle.loadString(_labelsPath);
    _labels = labelData
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    _isLoaded = true;
  }

  // =========================
  // PUBLIC API
  // =========================
  Future<List<KiranaDetection>> analyzeImage({
    required String imagePath,
    required List<String> inventoryNames,
  }) async {
    await _loadModel();

    final result = await _predict(imagePath);

    return [
      KiranaDetection(
        label: result['label'],
        confidence: result['confidence'],
        suggestedQuantity: 1,
      )
    ];
  }

  // =========================
  // CORE PREDICTION
  // =========================
  Future<Map<String, dynamic>> _predict(String imagePath) async {
    final interpreter = _interpreter!;

    // Input shape
    final inputShape = interpreter.getInputTensor(0).shape;
    final height = inputShape[1];
    final width = inputShape[2];

    // Load image
    final image = img.decodeImage(File(imagePath).readAsBytesSync())!;
    final resized = img.copyResize(image, width: width, height: height);

    // Build input (FLOAT MODEL)
    final input = List.generate(
      1,
      (_) => List.generate(
        height,
        (y) => List.generate(
          width,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );

    // Output
    final outputShape = interpreter.getOutputTensor(0).shape;
    final outputSize = outputShape.last;

    final output = List.generate(1, (_) => List.filled(outputSize, 0.0));

    // Run inference
    interpreter.run(input, output);

    final scores = List<double>.from(output[0]);

    // Argmax
    int maxIndex = 0;
    double maxScore = scores[0];

    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > maxScore) {
        maxScore = scores[i];
        maxIndex = i;
      }
    }

    return {
      "label": _labels[maxIndex],
      "confidence": maxScore,
    };
  }

  // =========================
  // CLEANUP
  // =========================
  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}