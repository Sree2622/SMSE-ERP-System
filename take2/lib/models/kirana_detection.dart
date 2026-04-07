class KiranaDetection {
  const KiranaDetection({
    required this.label,
    required this.confidence,
    this.suggestedQuantity = 1,
  });

  final String label;
  final double confidence;
  final int suggestedQuantity;

  factory KiranaDetection.fromJson(Map<String, dynamic> json) {
    return KiranaDetection(
      label: (json['label'] ?? '').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      suggestedQuantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}
