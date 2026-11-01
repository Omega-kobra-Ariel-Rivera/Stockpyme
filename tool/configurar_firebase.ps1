# StockPyme — crea lib/firebase_options.dart y android/app/google-services.json
# usando la consola de Firebase (reemplaza a "flutterfire configure").
#
# Uso, en la carpeta del proyecto (con "firebase login" ya hecho):
#   powershell -ExecutionPolicy Bypass -File tool\configurar_firebase.ps1

$ErrorActionPreference = 'Stop'
$project = 'stockpyme'
$package = 'cl.riverasystems.stock_pyme'

function Invoke-FirebaseJson([string[]]$FirebaseArgs) {
    $raw = & firebase @FirebaseArgs --project $project --json 2>$null | Out-String
    $start = $raw.IndexOf('{')
    if ($start -lt 0) { throw "Firebase no respondió: firebase $($FirebaseArgs -join ' ')" }
    $data = $raw.Substring($start) | ConvertFrom-Json
    if ($data.status -ne 'success') { throw "Firebase devolvió un error: $raw" }
    return $data.result
}

function Find-App($apps, [string]$platform) {
    return $apps | Where-Object { $_.platform -eq $platform } | Select-Object -First 1
}

Write-Host '1/4 Buscando las apps del proyecto stockpyme...' -ForegroundColor Cyan
$apps = Invoke-FirebaseJson @('apps:list')

$android = $apps | Where-Object { $_.platform -eq 'ANDROID' -and $_.packageName -eq $package } | Select-Object -First 1
if (-not $android) { $android = Find-App $apps 'ANDROID' }
if (-not $android) {
    Write-Host '   Creando la app Android...'
    Invoke-FirebaseJson @('apps:create', 'ANDROID', 'StockPyme', '--package-name', $package) | Out-Null
    $apps = Invoke-FirebaseJson @('apps:list')
    $android = Find-App $apps 'ANDROID'
}

$web = Find-App $apps 'WEB'
if (-not $web) {
    Write-Host '   Creando la app web (también la usa Windows)...'
    Invoke-FirebaseJson @('apps:create', 'WEB', 'StockPyme web') | Out-Null
    $apps = Invoke-FirebaseJson @('apps:list')
    $web = Find-App $apps 'WEB'
}
if (-not $android -or -not $web) { throw 'No se encontraron las apps Android y web.' }
Write-Host "   Android: $($android.appId)"
Write-Host "   Web:     $($web.appId)"

Write-Host '2/4 Leyendo la configuración Android...' -ForegroundColor Cyan
$androidCfg = Invoke-FirebaseJson @('apps:sdkconfig', 'ANDROID', $android.appId)
$googleServices = $androidCfg.fileContents
$gs = $googleServices | ConvertFrom-Json
$client = $gs.client | Where-Object { $_.client_info.android_client_info.package_name -eq $package } | Select-Object -First 1
if (-not $client) { $client = $gs.client | Select-Object -First 1 }
$aApiKey = $client.api_key[0].current_key
$aAppId = $client.client_info.mobilesdk_app_id
$senderId = $gs.project_info.project_number
$bucket = $gs.project_info.storage_bucket
New-Item -ItemType Directory -Force -Path 'android\app' | Out-Null
[IO.File]::WriteAllText((Join-Path (Get-Location) 'android\app\google-services.json'), $googleServices)

Write-Host '3/4 Leyendo la configuración web...' -ForegroundColor Cyan
$webCfg = Invoke-FirebaseJson @('apps:sdkconfig', 'WEB', $web.appId)
$w = $webCfg.sdkConfig
if (-not $w) {
    $text = $webCfg.fileContents
    $w = [pscustomobject]@{}
    foreach ($key in 'apiKey', 'authDomain', 'projectId', 'storageBucket', 'messagingSenderId', 'appId', 'measurementId') {
        $m = [regex]::Match($text, '"?' + $key + '"?\s*:\s*"([^"]+)"')
        if ($m.Success) { $w | Add-Member -NotePropertyName $key -NotePropertyValue $m.Groups[1].Value }
    }
}
if (-not $w.apiKey -or -not $w.appId) { throw 'No se pudo leer la configuración web.' }
$measurement = ''
if ($w.measurementId) { $measurement = "`n    measurementId: '$($w.measurementId)'," }

Write-Host '4/4 Escribiendo lib\firebase_options.dart...' -ForegroundColor Cyan
$dart = @"
// Generado por tool/configurar_firebase.ps1 para el proyecto Firebase "$project".
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'StockPyme no tiene Firebase configurado para esta plataforma.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '$aApiKey',
    appId: '$aAppId',
    messagingSenderId: '$senderId',
    projectId: '$project',
    storageBucket: '$bucket',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '$($w.apiKey)',
    appId: '$($w.appId)',
    messagingSenderId: '$($w.messagingSenderId)',
    projectId: '$($w.projectId)',
    authDomain: '$($w.authDomain)',
    storageBucket: '$($w.storageBucket)',$measurement
  );

  // Windows usa la configuración de la app web (igual que flutterfire).
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: '$($w.apiKey)',
    appId: '$($w.appId)',
    messagingSenderId: '$($w.messagingSenderId)',
    projectId: '$($w.projectId)',
    authDomain: '$($w.authDomain)',
    storageBucket: '$($w.storageBucket)',$measurement
  );
}
"@
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path (Get-Location) 'lib\firebase_options.dart'), $dart, $utf8)

Write-Host ''
Write-Host 'Listo. Firebase quedó configurado para Android, web y Windows.' -ForegroundColor Green
Write-Host 'Ahora sube los cambios: git add . ; git commit -m "Firebase configurado" ; git push'
