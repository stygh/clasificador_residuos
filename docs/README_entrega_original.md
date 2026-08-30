# Entrega 09 — Flutter + Cloud Run

Implementación de la aplicación móvil del TFE **Clasificador visual de residuos sólidos**.

## Arquitectura

Flutter → fotografía optimizada → Base64 → JSON → HTTPS POST → Cloud Run → FastAPI → TensorFlow → JSON → Flutter.

## Contrato utilizado

- URL base predeterminada: `https://residuos-api-b6ozclc6xq-ue.a.run.app`
- Endpoint: `POST /predict`
- Encabezado: `Content-Type: application/json; charset=UTF-8`
- Cuerpo:

```json
{
  "fileName": "residuo.jpg",
  "imageBase64": "/9j/4AAQSk..."
}
```

El campo `imageBase64` fue comprobado como obligatorio en FastAPI.


## Creación automática en Windows

Después de descomprimir el paquete, puede crear el proyecto completo con:

```powershell
.\scripts\create_project_windows.ps1
```

El script ejecuta `flutter create`, copia la solución, aplica los permisos y ejecuta `flutter pub get`, `flutter analyze` y `flutter test`.

## Cómo convertir esta entrega en un proyecto Flutter ejecutable

1. Instale Flutter y Android Studio.
2. Cree el proyecto base:

```powershell
flutter create clasificador_residuos
```

3. Copie a ese proyecto las carpetas y archivos incluidos aquí:

- `lib/`
- `test/`
- `pubspec.yaml`
- `analysis_options.yaml`

4. En `android/app/src/main/AndroidManifest.xml`, inserte el contenido de:

`platform_config/AndroidManifest.xml.fragment`

5. Para iOS, inserte el contenido de:

`platform_config/Info.plist.fragment`

6. Instale las dependencias:

```powershell
flutter pub get
```

7. Conecte un teléfono Android con depuración USB y confirme:

```powershell
flutter devices
```

8. Ejecute:

```powershell
flutter run --dart-define=API_BASE_URL=https://residuos-api-b6ozclc6xq-ue.a.run.app
```

También puede utilizar `scripts/run_android.ps1`.

## Funcionalidades implementadas

- Captura desde la cámara.
- Selección desde galería.
- Recuperación de imagen perdida en Android.
- Corrección de orientación EXIF.
- Redimensionamiento a un máximo de 1024 px.
- Compresión JPEG al 85 %.
- Almacenamiento temporal.
- Conversión Base64.
- Solicitud HTTPS con timeout de 60 segundos.
- Manejo de HTTP 400, 401, 403, 404, 413, 422, 429 y 5xx.
- Deserialización flexible de la respuesta JSON.
- Visualización de clase, confianza y probabilidades.
- Indicadores de carga y mensajes comprensibles.

## Verificaciones recomendadas

```powershell
flutter analyze
flutter test
```

## Nota sobre Android

La documentación actual de `image_picker` indica que no requiere configuración adicional para cámara/galería en Android. Sí debe conservarse el permiso `INTERNET` para comunicarse con Cloud Run.
