class PredictionResponse {
  const PredictionResponse({
    required this.success,
    required this.fileName,
    required this.classIndex,
    required this.className,
    required this.classSpanish,
    required this.confidence,
    required this.confidencePercentage,
    required this.probabilities,
  });

  final bool success;
  final String fileName;
  final int classIndex;
  final String className;
  final String classSpanish;
  final double confidence;
  final double confidencePercentage;
  final Map<String, double> probabilities;

  factory PredictionResponse.fromJson(Map<String, dynamic> json) {
    final double confidence = _asDouble(json['confidence']);
    final double percentageFromApi = _asDouble(
      json['confidencePercentage'] ?? json['confidence_percentage'],
    );

    final dynamic rawProbabilities = json['probabilities'];
    final Map<String, double> probabilities = rawProbabilities is Map
        ? rawProbabilities.map<String, double>(
            (dynamic key, dynamic value) => MapEntry(
              key.toString(),
              _asDouble(value),
            ),
          )
        : const <String, double>{};

    final String technicalClass =
        (json['class'] ?? json['className'] ?? json['prediction'] ?? '')
            .toString();

    return PredictionResponse(
      success: json['success'] is bool ? json['success'] as bool : true,
      fileName: (json['fileName'] ?? json['filename'] ?? '').toString(),
      classIndex: _asInt(json['classIndex'] ?? json['class_index']),
      className: technicalClass,
      classSpanish:
          (json['classSpanish'] ?? json['class_spanish'] ?? technicalClass)
              .toString(),
      confidence: confidence,
      confidencePercentage: percentageFromApi > 0
          ? percentageFromApi
          : (confidence <= 1 ? confidence * 100 : confidence),
      probabilities: probabilities,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? -1;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
