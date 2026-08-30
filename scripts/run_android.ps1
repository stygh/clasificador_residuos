$ErrorActionPreference = "Stop"
$ApiUrl = "https://residuos-api-b6ozclc6xq-ue.a.run.app"
flutter pub get
flutter analyze
flutter run --dart-define=API_BASE_URL=$ApiUrl
