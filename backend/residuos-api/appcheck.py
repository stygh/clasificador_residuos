"""Verificación del testigo de Firebase App Check en el servicio de inferencia.

Comprueba la firma RSA del token contra el juego de claves públicas de Firebase,
así como el emisor, la audiencia y la caducidad. Rechaza las solicitudes que no
presentan testigo (401) y aquellas cuyo testigo no es válido (403).
"""

import os

import jwt
from fastapi import Header, HTTPException
from jwt import PyJWKClient

NUMERO_PROYECTO = os.environ["FIREBASE_PROJECT_NUMBER"]
ID_PROYECTO = os.environ["FIREBASE_PROJECT_ID"]

EMISOR = f"https://firebaseappcheck.googleapis.com/{NUMERO_PROYECTO}"
AUDIENCIA = [f"projects/{NUMERO_PROYECTO}", f"projects/{ID_PROYECTO}"]

_claves = PyJWKClient(
    "https://firebaseappcheck.googleapis.com/v1/jwks",
    cache_keys=True,
)


async def verificar_app_check(
    x_firebase_appcheck: str | None = Header(default=None),
) -> str:
    if not x_firebase_appcheck:
        raise HTTPException(
            status_code=401,
            detail="La solicitud no presenta testigo de App Check.",
        )
    try:
        clave = _claves.get_signing_key_from_jwt(x_firebase_appcheck)
        reclamaciones = jwt.decode(
            x_firebase_appcheck,
            clave.key,
            algorithms=["RS256"],
            audience=AUDIENCIA,
            issuer=EMISOR,
        )
    except Exception:
        raise HTTPException(
            status_code=403,
            detail="El testigo de App Check no es válido.",
        )
    return reclamaciones["sub"]
