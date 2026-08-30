#!/usr/bin/env bash
set -euo pipefail
API_URL="https://residuos-api-b6ozclc6xq-ue.a.run.app"
flutter pub get
flutter analyze
flutter run --dart-define=API_BASE_URL="$API_URL"
