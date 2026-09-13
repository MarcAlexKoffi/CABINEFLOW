param(
    [string]$DeviceId = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

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

$devices = @(& $adb devices | Select-String '\tdevice$' | ForEach-Object { ($_ -split '\s+')[0] })
if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    if ($devices.Count -eq 0) { throw 'Aucun appareil Android ADB detecte.' }
    if ($devices.Count -gt 1) { throw 'Plusieurs appareils sont detectes. Relance avec -DeviceId <serial>.' }
    $DeviceId = $devices[0]
}

Write-Host 'Filtre actif : IzyTel / FCM / Flutter / Supabase / Firebase.' -ForegroundColor Cyan
& $adb -s $DeviceId logcat -c
& $adb -s $DeviceId logcat | Select-String -Pattern 'IzyTel|FCM|flutter|Supabase|FirebaseAuth|Firestore|Postgrest'
