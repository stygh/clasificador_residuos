import base64
import binascii
import io
import json
from pathlib import Path
from typing import Any

import numpy as np
import tensorflow as tf
from fastapi import FastAPI, HTTPException
from PIL import Image, UnidentifiedImageError
from pydantic import BaseModel, Field


# -------------------------------------------------------
# Configuración
# -------------------------------------------------------

MODEL_PATH = Path("/app/modelo")
MAX_IMAGE_BYTES = 10 * 1024 * 1024

DEFAULT_CLASSES = [
    "cardboard",
    "clothes",
    "glass",
    "metal",
    "organic",
    "paper",
    "shoes",
    "trash",
]

SPANISH_NAMES = {
    "cardboard": "Cartón",
    "clothes": "Ropa",
    "glass": "Vidrio",
    "metal": "Metal",
    "organic": "Orgánico",
    "paper": "Papel",
    "shoes": "Calzado",
    "trash": "Basura",
}


# -------------------------------------------------------
# Cargar nombres de clases
# -------------------------------------------------------

def load_class_names() -> list[str]:
    possible_files = [
        MODEL_PATH / "assets.extra" / "class_names.json",
        MODEL_PATH / "assets" / "class_names.json",
    ]

    for file_path in possible_files:
        if not file_path.exists():
            continue

        with file_path.open("r", encoding="utf-8") as file:
            data = json.load(file)

        if isinstance(data, list) and len(data) == 8:
            return [str(item) for item in data]

        if isinstance(data, dict):
            values = data.get("class_names") or data.get("classes")

            if isinstance(values, list) and len(values) == 8:
                return [str(item) for item in values]

    return DEFAULT_CLASSES


# -------------------------------------------------------
# Cargar modelo una sola vez
# -------------------------------------------------------

print("==========================================")
print(" Cargando modelo TensorFlow...")
print("==========================================")

if not MODEL_PATH.exists():
    raise RuntimeError(
        f"No se encontró el modelo en: {MODEL_PATH}"
    )

loaded_model = tf.saved_model.load(str(MODEL_PATH))

if "serving_default" not in loaded_model.signatures:
    raise RuntimeError(
        "El SavedModel no contiene la firma serving_default."
    )

predict_fn = loaded_model.signatures["serving_default"]
class_names = load_class_names()

print("Modelo cargado correctamente.")
print("Clases:", class_names)
print("Firma de entrada:", predict_fn.structured_input_signature)
print("Firma de salida:", predict_fn.structured_outputs)


# -------------------------------------------------------
# FastAPI
# -------------------------------------------------------

app = FastAPI(
    title="API de clasificación de residuos",
    description=(
        "Servicio de inferencia para un modelo EfficientNetV2B0 "
        "entrenado en Vertex AI."
    ),
    version="1.1.0",
)


# -------------------------------------------------------
# Modelos de solicitud
# -------------------------------------------------------

class PredictionRequest(BaseModel):
    imageBase64: str = Field(
        ...,
        description="Imagen JPG o PNG codificada en Base64.",
    )
    fileName: str | None = Field(
        default=None,
        description="Nombre opcional del archivo enviado.",
    )


# -------------------------------------------------------
# Endpoints informativos
# -------------------------------------------------------

@app.get("/")
def home() -> dict[str, Any]:
    return {
        "status": "OK",
        "service": "clasificador-residuos",
        "model": "EfficientNetV2B0",
        "inputShape": [224, 224, 3],
        "inputRange": "0-255",
        "classes": class_names,
    }


@app.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "healthy"
    }


# -------------------------------------------------------
# Preprocesamiento
# -------------------------------------------------------

def decode_base64_image(encoded_image: str) -> bytes:
    """
    Decodifica una imagen Base64.

    También acepta el formato:
    data:image/jpeg;base64,/9j/4AAQ...
    """

    if encoded_image.startswith("data:"):
        try:
            encoded_image = encoded_image.split(",", 1)[1]
        except IndexError as exc:
            raise ValueError(
                "El encabezado Data URL no es válido."
            ) from exc

    try:
        image_bytes = base64.b64decode(
            encoded_image,
            validate=True,
        )
    except (binascii.Error, ValueError) as exc:
        raise ValueError(
            "La cadena Base64 no es válida."
        ) from exc

    if not image_bytes:
        raise ValueError(
            "La imagen recibida está vacía."
        )

    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise ValueError(
            "La imagen supera el límite permitido de 10 MB."
        )

    return image_bytes


def preprocess_image(image_bytes: bytes) -> tf.Tensor:
    """
    Prepara la imagen para el modelo.

    El entrenamiento utilizó:
    - RGB
    - tamaño 224 x 224
    - dtype float32
    - valores de píxel en rango 0-255

    No se divide entre 255 porque EfficientNetV2B0 fue creado con
    include_preprocessing=True.
    """

    try:
        with Image.open(io.BytesIO(image_bytes)) as image:
            image = image.convert("RGB")
            image = image.resize(
                (224, 224),
                Image.Resampling.BILINEAR,
            )

            image_array = np.asarray(
                image,
                dtype=np.float32,
            )

    except (UnidentifiedImageError, OSError) as exc:
        raise ValueError(
            "El archivo recibido no es una imagen JPG o PNG válida."
        ) from exc

    # IMPORTANTE:
    # No normalizar con /255.0.
    # El modelo espera float32 en rango 0-255.
    image_array = np.expand_dims(
        image_array,
        axis=0,
    )

    return tf.convert_to_tensor(
        image_array,
        dtype=tf.float32,
    )


# -------------------------------------------------------
# Predicción
# -------------------------------------------------------

@app.post("/predict")
def predict(
    request: PredictionRequest,
) -> dict[str, Any]:

    try:
        image_bytes = decode_base64_image(
            request.imageBase64
        )

        tensor = preprocess_image(
            image_bytes
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc

    try:
        prediction = predict_fn(
            image=tensor
        )

        if "probabilities" not in prediction:
            raise RuntimeError(
                "La salida del modelo no contiene la clave "
                "'probabilities'."
            )

        probabilities = (
            prediction["probabilities"]
            .numpy()[0]
            .astype(float)
        )

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Error durante la inferencia: {exc}",
        ) from exc

    if len(probabilities) != len(class_names):
        raise HTTPException(
            status_code=500,
            detail=(
                "La cantidad de probabilidades no coincide "
                "con la cantidad de clases."
            ),
        )

    predicted_index = int(
        np.argmax(probabilities)
    )

    predicted_class = class_names[
        predicted_index
    ]

    confidence = float(
        probabilities[predicted_index]
    )

    probability_map = {
        class_names[index]: round(
            float(probabilities[index]),
            6,
        )
        for index in range(len(class_names))
    }

    return {
        "success": True,
        "fileName": request.fileName,
        "classIndex": predicted_index,
        "class": predicted_class,
        "classSpanish": SPANISH_NAMES.get(
            predicted_class,
            predicted_class,
        ),
        "confidence": confidence,
        "confidencePercentage": round(
            confidence * 100,
            2,
        ),
        "probabilities": probability_map,
    }