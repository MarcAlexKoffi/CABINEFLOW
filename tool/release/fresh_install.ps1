param(
    [string]$DeviceId = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$apk = Join-Path $projectRoot 'dist\IzyTel-1.0.0_1-release.apk'
$packageName = 'com.izytel.app'

function Resolve-Adb {
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($sdkHome in @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME)) {
        if (-not [string]::IsNullOrWhiteSpace($sdkHome)) {
            $candidates.Add((Join-Path $sdkHome 'platform-tools\adb.exe'))
        }
    }

    $localPropertiesPath = Join-Path $projectRoot 'android\local.properties'
    if (Test-Path $localPropertiesPath) {
        $sdkLine = Get-Content $localPropertiesPath | Where-Object { $_ -like 'sdk.dir=*' } | Select-Object -First 1
        if ($sdkLine) {
            $sdkDir = ($sdkLine.Substring('sdk.dir='.Length) -replace '\\\\', '\')
            $candidates.Add((Join-Path $sdkDir 'platform-tools\adb.exe'))
        }
    }

    if ($env:LOCALAPPDATA) {
        $candidates.Add((Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'))
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }
    }
    return $null
}

$adb = Resolve-Adb
if (-not $adb) { throw 'adb est introuvable. Verifie android/local.properties ou ANDROID_SDK_ROOT.' }
Write-Host "adb detecte : $adb" -ForegroundColor DarkGray

if (-not (Test-Path $apk)) {
    throw "APK release introuvable : $apk. Lance d abord tool/release/build_release.ps1."
}

$devices = @(& $adb devices | Select-String '\tdevice$' | ForEach-Object { ($_ -split '\s+')[0] })
if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    if ($devices.Count -eq 0) { throw 'Aucun appareil Android ADB detecte.' }
    if ($devices.Count -gt 1) { throw 'Plusieurs appareils sont detectes. Relance avec -DeviceId <serial>.' }
    $DeviceId = $devices[0]
}

Write-Host "Appareil : $DeviceId" -ForegroundColor Cyan
Write-Host 'Cette operation DESINSTALLE com.izytel.app et efface ses donnees locales avant la fresh install.' -ForegroundColor Yellow
$answer = Read-Host 'Tape OUI pour continuer'
if ($answer -ne 'OUI') { throw 'Fresh install annulee.' }

& $adb -s $DeviceId uninstall $packageName | Out-Host
& $adb -s $DeviceId install $apk | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Installation de l APK release echouee.' }

$path = (& $adb -s $DeviceId shell pm path $packageName | Out-String).Trim()
if ($path -notmatch '^package:') { throw 'Le package com.izytel.app n est pas installe.' }

& $adb -s $DeviceId shell monkey -p $packageName -c android.intent.category.LAUNCHER 1 | Out-Host
Write-Host ''
Write-Host 'Fresh install terminee. Effectue maintenant le parcours manuel de PHASE4_RELEASE_ACCEPTANCE.md.' -ForegroundColor Green
