import 'package:clasificador_residuos/models/prediction_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('convierte el JSON de Cloud Run en PredictionResponse', () {
    final PredictionResponse response = PredictionResponse.fromJson(
      <String, dynamic>{
        'success': true,
        'fileName': 'vidrio.jpg',
        'classIndex': 2,
        'class': 'glass',
        'classSpanish': 'Vidrio',
        'confidence': 0.9642,
        'confidencePercentage': 96.42,
        'probabilities': <String, dynamic>{
          'glass': 0.9642,
          'paper': 0.0101,
        },
      },
    );

    expect(response.success, isTrue);
    expect(response.className, 'glass');
    expect(response.classSpanish, 'Vidrio');
    expect(response.confidencePercentage, closeTo(96.42, 0.001));
    expect(response.probabilities['glass'], closeTo(0.9642, 0.0001));
  });
}
