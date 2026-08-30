# Resumen técnico de implementación

## Componentes

| Archivo | Responsabilidad |
|---|---|
| `lib/config/api_config.dart` | URL, endpoint y timeout |
| `lib/models/prediction_response.dart` | Conversión de JSON a objeto Dart |
| `lib/services/api_service.dart` | Codificación Base64, POST HTTPS y errores |
| `lib/utils/image_utils.dart` | Orientación, redimensionamiento y JPEG |
| `lib/pages/home_page.dart` | Cámara, galería, estado e interfaz |
| `lib/main.dart` | Inicio de la aplicación y tema |

## Flujo de ejecución

1. El usuario toma o selecciona una foto.
2. La aplicación corrige la orientación de la imagen.
3. La imagen se reduce a un máximo de 1024 px y se comprime a JPEG.
4. Flutter lee los bytes y genera la cadena Base64.
5. Se envía un JSON a `POST /predict`.
6. Cloud Run ejecuta FastAPI y el modelo TensorFlow.
7. Flutter convierte el JSON recibido en `PredictionResponse`.
8. La interfaz presenta la clase, confianza y probabilidades.
