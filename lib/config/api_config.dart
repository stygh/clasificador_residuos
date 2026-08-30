/// Configuración centralizada de la API desplegada en Google Cloud Run.
///
/// La URL puede sustituirse en tiempo de ejecución mediante:
/// flutter run --dart-define=API_BASE_URL=https://...a.run.app
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://residuos-api-b6ozclc6xq-ue.a.run.app',
  );

  static const String predictPath = '/predict';

  static Uri get predictUri => Uri.parse('$baseUrl$predictPath');

  static const Duration requestTimeout = Duration(seconds: 60);
}
