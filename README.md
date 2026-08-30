# Clasificador Visual de Residuos Sólidos — Aplicación móvil

Aplicación Flutter multiplataforma que clasifica residuos sólidos a partir de una fotografía, consumiendo un servicio de inferencia desplegado en Google Cloud Run.

Este repositorio corresponde al **componente cliente** del Trabajo de Fin de Estudios *Clasificador Visual Progresivo de Residuos Sólidos* (UNIR, 2026). El componente analítico —preparación de datos, entrenamiento y despliegue del modelo— se encuentra en un repositorio separado que se enlaza al final.

---

## Qué hace

El usuario toma una fotografía de un residuo y la aplicación le devuelve, en menos de dos segundos, la categoría del material junto con el nivel de confianza y la distribución de probabilidades sobre las ocho categorías del modelo.

```
Cámara / galería
   → corrección de orientación EXIF
   → redimensionado a máx. 1024 px
   → compresión JPEG al 85 %          (≈ 200-300 KB)
   → codificación Base64
   → POST /predict  (HTTPS)
        → Cloud Run · FastAPI · TensorFlow · EfficientNetV2B0
   → JSON con clase y probabilidades
   → pantalla de resultado
```

La aplicación **no contiene el modelo**. Toda la inferencia ocurre en el servidor, lo que permite actualizar el modelo sin publicar una versión nueva de la app y evita cargar dispositivos de gama media con el coste del cómputo.

---

## Modelo y categorías

| | |
|---|---|
| Arquitectura | EfficientNetV2B0 preentrenada en ImageNet |
| Marco | TensorFlow 2.15.0 |
| Entrada | 224 × 224 × 3 |
| Categorías | 8 |
| Exactitud (partición de prueba, n = 1.511) | **96,69 %** |
| F1-score macro | **0,9505** |
| Tamaño del artefacto | 43,5 MB |

| Clase | En la interfaz | Flujo de disposición |
|---|---|---|
| `cardboard` | Cartón | Reciclable — papel y cartón |
| `paper` | Papel | Reciclable — papel y cartón |
| `glass` | Vidrio | Reciclable — vidrio |
| `metal` | Metal | Reciclable — envases metálicos |
| `organic` | Orgánico | Compostable |
| `clothes` | Textil | Punto limpio — reutilización textil |
| `shoes` | Calzado | Punto limpio — reutilización textil |
| `trash` | Resto | Fracción resto — vertedero |

Las métricas completas del modelo, con la matriz de confusión, las curvas ROC y el historial de entrenamiento, están en [`docs/metricas/`](docs/metricas).

---

## Estructura del repositorio

```
lib/
├── config/api_config.dart          URL base, endpoint y timeout            (16 líneas)
├── models/prediction_response.dart JSON → objeto Dart, tolerante a cambios (68)
├── services/api_service.dart       Base64, POST HTTPS y gestión de errores (140)
├── utils/image_utils.dart          EXIF, redimensionado y compresión       (56)
├── pages/home_page.dart            Cámara, galería, estados e interfaz     (352)
└── main.dart                       Arranque y tema                         (25)
test/
└── prediction_response_test.dart   Pruebas unitarias de deserialización    (28)
platform_config/
├── AndroidManifest.xml.fragment    Permiso INTERNET
└── Info.plist.fragment             Descripciones de uso de cámara y galería
scripts/
├── create_project_windows.ps1      Crea el proyecto Flutter completo
├── run_android.ps1                 Ejecuta en Android desde Windows
└── run_android.sh                  Ejecuta en Android desde Unix
docs/metricas/                      Métricas y gráficas del modelo desplegado
```

Total: **685 líneas de Dart**, sin contar el andamiaje generado por Flutter.

El directorio del proyecto Flutter generado no se versiona: se reconstruye con `flutter create` más el script de `scripts/`, y así el repositorio contiene únicamente el código escrito para este trabajo.

---

## Requisitos

- Flutter SDK `>=3.4.0 <4.0.0`
- Android Studio (para Android) o Xcode (para iOS)
- Un dispositivo físico o emulador con acceso a red

### Dependencias

| Paquete | Versión | Función |
|---|---|---|
| `http` | ^1.6.0 | Cliente HTTPS contra el servicio de inferencia |
| `image_picker` | ^1.2.3 | Acceso a cámara y galería |
| `image` | ^4.9.1 | Decodificación, rotación, redimensionado y compresión |
| `path_provider` | ^2.1.6 | Directorio temporal para la imagen optimizada |
| `cupertino_icons` | ^1.0.8 | Iconografía |
| `flutter_lints` | ^6.0.0 | Análisis estático |

---

## Puesta en marcha

```bash
git clone https://github.com/stygh/clasificador_residuos.git
cd clasificador_residuos
```

### Opción A — script automático (Windows)

```powershell
.\scripts\create_project_windows.ps1
```

Crea el proyecto Flutter, copia la solución, aplica los permisos de plataforma y ejecuta `flutter pub get`, `flutter analyze` y `flutter test`.

### Opción B — manual

```bash
flutter create clasificador_residuos
# copiar lib/, test/, pubspec.yaml y analysis_options.yaml al proyecto creado
cd clasificador_residuos
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run --dart-define=API_BASE_URL=https://residuos-api-b6ozclc6xq-ue.a.run.app
```

**Android:** inserta el contenido de `platform_config/AndroidManifest.xml.fragment` en `android/app/src/main/AndroidManifest.xml`. Sin el permiso `INTERNET` la aplicación no puede comunicarse con el servicio.

**iOS:** inserta el contenido de `platform_config/Info.plist.fragment` en `ios/Runner/Info.plist`. Sin las descripciones de uso, el sistema deniega el acceso a la cámara y a la galería.

---

## Contrato del servicio de inferencia

Base: `https://residuos-api-b6ozclc6xq-ue.a.run.app` — configurable en tiempo de compilación con `--dart-define=API_BASE_URL=...`

| Operación | Método | Descripción |
|---|---|---|
| `/` | GET | Estado, modelo cargado, forma de la entrada y lista de categorías |
| `/health` | GET | Comprobación de vitalidad |
| `/predict` | POST | Clasifica una imagen codificada en Base64 |
| `/docs` | GET | Documentación interactiva (Swagger UI) |

**Petición**

```json
POST /predict
Content-Type: application/json; charset=UTF-8

{
  "fileName": "residuo.jpg",
  "imageBase64": "/9j/4AAQSkZJRgABAQAA..."
}
```

**Respuesta (200)**

```json
{
  "success": true,
  "fileName": "residuo.jpg",
  "classIndex": 4,
  "class": "organic",
  "classSpanish": "Orgánico",
  "confidence": 0.9710298180580139,
  "confidencePercentage": 97.1,
  "probabilities": {
    "cardboard": 0.021737, "clothes": 0.000019,
    "glass":     0.000587, "metal":   0.001993,
    "organic":   0.971030, "paper":   0.004254,
    "shoes":     0.000192, "trash":   0.000189
  }
}
```

El campo `imageBase64` es obligatorio. El cliente admite los nombres de campo tanto en `camelCase` como en `snake_case`, y construye el mapa de probabilidades a partir de las claves que devuelva el servicio: **el número y el nombre de las categorías no están fijados en el código**, de modo que un cambio en la taxonomía del modelo no obliga a publicar una versión nueva de la aplicación.

La aplicación traduce a mensajes comprensibles los códigos `400`, `401`, `403`, `404`, `413`, `422`, `429` y la serie `5xx`. El tiempo máximo de espera del cliente es de 60 segundos; no es el objetivo de latencia, sino el límite a partir del cual la petición se da por fallida.

---

## Rendimiento

Medición del tramo de servidor, 15 peticiones consecutivas con una imagen JPEG de 263 KB:

| Condición | n | Mínimo | Media | Mediana | Máximo |
|---|---|---|---|---|---|
| Primera petición (arranque en frío) | 1 | — | 1.549 ms | — | 1.549 ms |
| Peticiones en caliente | 14 | 259 ms | 409 ms | 442 ms | 499 ms |

El servicio está configurado con un mínimo de cero instancias, por lo que la primera petición tras un periodo de inactividad paga el arranque en frío del contenedor.

---

## Limitaciones conocidas

- **No existe una categoría de plástico.** Las fuentes públicas empleadas no la etiquetan de forma separable con garantías. Es la carencia funcional más relevante del sistema.
- El conjunto de entrenamiento procede íntegramente de fuentes públicas, con sesgo hacia envases europeos y norteamericanos.
- La correspondencia entre categoría y contenedor está definida pero **aún no implementada en la interfaz**: la app muestra la categoría, no el flujo de disposición.
- El sistema requiere conexión de datos: no hay inferencia local en el dispositivo.
- El endpoint de inferencia es público y sin autenticación, decisión aceptable para un prototipo académico.

---

## Componente analítico

Preparación de datos, entrenamiento, evaluación y despliegue del modelo:

El componente analítico corresponde a otro integrante del equipo y se publica en un
repositorio independiente. Su dirección se recoge en el apartado A.7 de la memoria.
Este apartado se actualizará con el enlace en cuanto esté disponible.

---

## Autoría

Trabajo de Fin de Estudios — UNIR, 2026.
Componente cliente desarrollado por **Daniel S. Giraldo Herrera**.
