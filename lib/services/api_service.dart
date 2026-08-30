import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/prediction_response.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PredictionResponse> predict(File imageFile) async {
    if (!await imageFile.exists()) {
      throw const ApiException(
        'La imagen seleccionada ya no se encuentra disponible.',
      );
    }

    final List<int> imageBytes = await imageFile.readAsBytes();
    if (imageBytes.isEmpty) {
      throw const ApiException('La imagen seleccionada está vacía.');
    }

    final Map<String, dynamic> requestBody = <String, dynamic>{
      'fileName': imageFile.uri.pathSegments.last,
      'imageBase64': base64Encode(imageBytes),
    };

    try {
      final http.Response response = await _client
          .post(
            ApiConfig.predictUri,
            headers: const <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(ApiConfig.requestTimeout);

      final String responseText = utf8.decode(response.bodyBytes);
      final Map<String, dynamic>? responseJson = _decodeJson(responseText);

      if (response.statusCode == 200) {
        if (responseJson == null) {
          throw const ApiException(
            'Cloud Run respondió, pero el contenido no es un JSON válido.',
          );
        }
        return PredictionResponse.fromJson(responseJson);
      }

      final String serverMessage = _extractServerMessage(responseJson);
      throw ApiException(
        _messageForStatus(response.statusCode, serverMessage),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado. Cloud Run tardó demasiado en responder.',
      );
    } on SocketException {
      throw const ApiException(
        'No fue posible conectarse con Cloud Run. Verifica la conexión a Internet.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Ocurrió un problema durante la comunicación HTTPS con Cloud Run.',
      );
    } on FormatException {
      throw const ApiException(
        'La respuesta recibida desde Cloud Run no tiene el formato esperado.',
      );
    }
  }

  Map<String, dynamic>? _decodeJson(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  String _extractServerMessage(Map<String, dynamic>? json) {
    if (json == null) return '';
    final dynamic detail = json['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      final dynamic first = detail.first;
      if (first is Map && first['msg'] != null) {
        return first['msg'].toString();
      }
    }
    return (json['message'] ?? json['error'] ?? '').toString();
  }

  String _messageForStatus(int statusCode, String serverMessage) {
    final String suffix = serverMessage.isEmpty ? '' : ' $serverMessage';
    switch (statusCode) {
      case 400:
        return 'La imagen o la solicitud no pudo ser procesada.$suffix';
      case 401:
      case 403:
        return 'Cloud Run rechazó la solicitud por falta de autorización.$suffix';
      case 404:
        return 'No se encontró el endpoint /predict en Cloud Run.$suffix';
      case 413:
        return 'La fotografía es demasiado grande para enviarla.$suffix';
      case 422:
        return 'La API rechazó el formato de los datos enviados.$suffix';
      case 429:
        return 'El servicio recibió demasiadas solicitudes. Inténtalo nuevamente.$suffix';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Cloud Run presentó un problema temporal durante la inferencia.$suffix';
      default:
        return 'La solicitud terminó con el código HTTP $statusCode.$suffix';
    }
  }

  void close() => _client.close();
}
