param(
  [string]$Destination = "$PWD\clasificador_residuos_app"
)

$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter no está disponible en PATH. Instala Flutter antes de ejecutar este script."
}

if (Test-Path $Destination) {
  throw "La carpeta de destino ya existe: $Destination"
}

Write-Host "Creando proyecto Flutter en $Destination..."
flutter create `
  --org com.tfe.residuos `
  --project-name clasificador_residuos `
  --platforms android,ios `
  $Destination

Copy-Item (Join-Path $SourceRoot "lib") $Destination -Recurse -Force
Copy-Item (Join-Path $SourceRoot "test") $Destination -Recurse -Force
Copy-Item (Join-Path $SourceRoot "pubspec.yaml") $Destination -Force
Copy-Item (Join-Path $SourceRoot "analysis_options.yaml") $Destination -Force

$ManifestPath = Join-Path $Destination "android\app\src\main\AndroidManifest.xml"
$Manifest = Get-Content $ManifestPath -Raw
if ($Manifest -notmatch 'android.permission.INTERNET') {
  $Manifest = $Manifest -replace '<manifest([^>]*)>', '<manifest$1>' + "`r`n    <uses-permission android:name=`"android.permission.INTERNET`" />"
  Set-Content -Path $ManifestPath -Value $Manifest -Encoding UTF8
}

$InfoPlistPath = Join-Path $Destination "ios\Runner\Info.plist"
$InfoPlist = Get-Content $InfoPlistPath -Raw
if ($InfoPlist -notmatch 'NSCameraUsageDescription') {
  $IosPermissions = @"
	<key>NSCameraUsageDescription</key>
	<string>La aplicación necesita acceder a la cámara para fotografiar residuos.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>La aplicación necesita acceder a la galería para seleccionar imágenes.</string>
"@
  $InfoPlist = $InfoPlist -replace '</dict>', "$IosPermissions`n</dict>"
  Set-Content -Path $InfoPlistPath -Value $InfoPlist -Encoding UTF8
}

Push-Location $Destination
try {
  flutter pub get
  flutter analyze
  flutter test
  Write-Host "Proyecto creado y verificado." -ForegroundColor Green
  Write-Host "Para ejecutarlo:" -ForegroundColor Cyan
  Write-Host "flutter run --dart-define=API_BASE_URL=https://residuos-api-b6ozclc6xq-ue.a.run.app"
}
finally {
  Pop-Location
}
