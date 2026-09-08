# Servicio de inferencia — `residuos-api`

Backend FastAPI que expone el modelo de clasificación de residuos sólidos y se
despliega como servicio en Google Cloud Run. Es el componente contra el que habla
la aplicación Flutter de este repositorio.

- **Servicio:** `residuos-api` · región `us-east1` · proyecto `py-residuos`
- **URL:** https://residuos-api-b6ozclc6xq-ue.a.run.app
- **Versión de la API:** 1.1.0 (OpenAPI en `/docs`)
- **Modelo:** EfficientNetV2B0, entrada 224 × 224 × 3, rango de píxel 0–255

## Operaciones

| Operación | Método | Descripción |
|---|---|---|
| `/` | GET | Estado, modelo cargado, forma y rango de la entrada y lista ordenada de categorías |
| `/health` | GET | Comprobación de vitalidad usada por la plataforma |
| `/predict` | POST | Clasifica una imagen codificada en Base64 |

### Petición

```json
POST /predict
{
  "fileName": "residuo.jpg",
  "imageBase64": "/9j/4AAQSkZJRgABAQAA..."
}
```

`imageBase64` es obligatorio. Se admite también el formato Data URL
(`data:image/jpeg;base64,...`). El límite por imagen es de 10 MB.

### Respuesta

```json
{
  "success": true,
  "fileName": "residuo.jpg",
  "classIndex": 4,
  "class": "organic",
  "classSpanish": "Orgánico",
  "confidence": 0.971030,
  "confidencePercentage": 97.1,
  "probabilities": { "cardboard": 0.021737, "...": 0.0 }
}
```

## Categorías

El vector de salida sigue este orden exacto, que se lee de
`class_names.json` dentro del SavedModel y, si no está presente, del valor por
defecto del código:

`cardboard`, `clothes`, `glass`, `metal`, `organic`, `paper`, `shoes`, `trash`

No existe una categoría de plástico. La razón está documentada en la memoria del
trabajo, en el apartado de limitaciones.

## Detalles de implementación

El modelo se carga una sola vez al arrancar el proceso, desde `/app/modelo`
dentro de la imagen del contenedor, y se invoca a través de la firma
`serving_default`.

El preprocesado convierte la imagen a RGB, la redimensiona a 224 × 224 con
interpolación bilineal y la entrega como `float32` en rango **0–255**. No se
divide entre 255: la red se construyó con `include_preprocessing=True` y aplica
la normalización internamente. Normalizar aquí degradaría la predicción sin
producir ningún error visible.

Los errores de imagen (Base64 inválido, formato no reconocido, tamaño excesivo)
se devuelven como `400`; los fallos durante la inferencia, como `500`.

## Configuración del despliegue

| Parámetro | Valor |
|---|---|
| CPU / memoria | 2 vCPU · 2 GiB |
| Simultaneidad | 160 peticiones por instancia |
| Tiempo de espera | 300 s |
| Escalado | mínimo 0, máximo 10 instancias |
| Puerto | 8080 |
| Autenticación | ninguna (endpoint público) |

Con el mínimo en cero instancias, la primera petición tras un periodo de
inactividad paga el arranque en frío del contenedor: unos 1,5 s frente a los
~440 ms de mediana en régimen sostenido.

## Artefactos asociados

El SavedModel desplegado y las métricas del entrenamiento residen en Cloud
Storage, bajo `gs://bkt-reciduos/`. Las métricas del modelo en producción están
copiadas en [`docs/metricas/`](../../docs/metricas) de este mismo repositorio.
