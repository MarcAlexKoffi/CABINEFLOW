param(
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$distDir = Join-Path $projectRoot 'dist'
$version = '1.0.0+1'
$artifactVersion = '1.0.0_1'
$packageName = 'com.izytel.app'
$cmdExe = if (-not [string]::IsNullOrWhiteSpace($env:ComSpec)) { $env:ComSpec } else { Join-Path $env:SystemRoot 'System32\cmd.exe' }

function Resolve-JavaRuntime {
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($javaHomeCandidate in @($env:JAVA_HOME, $env:JDK_HOME, $env:ANDROID_STUDIO_JDK)) {
        if (-not [string]::IsNullOrWhiteSpace($javaHomeCandidate)) {
            $candidates.Add((Join-Path $javaHomeCandidate 'bin\java.exe'))
        }
    }
    $javaCommand = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCommand) { $candidates.Add($javaCommand.Source) }

    if (Get-Command flutter -ErrorAction SilentlyContinue) {
        try {
            $savedPreference = $ErrorActionPreference
            $ErrorActionPreference = 'SilentlyContinue'
            $doctor = (& flutter doctor -v 2>&1 | Out-String)
            $ErrorActionPreference = $savedPreference
            $match = [regex]::Match($doctor, '(?im)Java binary at:\s*(.+?java(?:\.exe)?)\s*$')
            if ($match.Success) { $candidates.Add($match.Groups[1].Value.Trim().Trim('"')) }
        } catch {
            $ErrorActionPreference = $savedPreference
        }
    }

    $programFilesX86 = ${env:ProgramFiles(x86)}
    foreach ($candidate in @(
        (Join-Path $env:ProgramFiles 'Android\Android Studio\jbr\bin\java.exe'),
        (Join-Path $env:ProgramFiles 'Android\Android Studio\jre\bin\java.exe'),
        $(if ($programFilesX86) { Join-Path $programFilesX86 'Android\Android Studio\jbr\bin\java.exe' }),
        $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Programs\Android Studio\jbr\bin\java.exe' })
    )) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) { $candidates.Add($candidate) }
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path $candidate) {
            $javaPath = (Resolve-Path $candidate).Path
            $javaBin = Split-Path $javaPath -Parent
            $javaHome = Split-Path $javaBin -Parent
            return [pscustomobject]@{
                Java = $javaPath
                JavaBin = $javaBin
                JavaHome = $javaHome
                Jarsigner = Join-Path $javaBin 'jarsigner.exe'
            }
        }
    }
    return $null
}

function Invoke-CapturedCommand {
    param(
        [Parameter(Mandatory = $true)][string]$CommandLine,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [switch]$Echo
    )
    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        if ($Echo) { Write-Host "> $CommandLine" -ForegroundColor DarkGray }
        $process = Start-Process `
            -FilePath $cmdExe `
            -ArgumentList @('/d', '/s', '/c', $CommandLine) `
            -WorkingDirectory $WorkingDirectory `
            -NoNewWindow `
            -Wait `
            -PassThru `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
        $stdout = if (Test-Path $stdoutPath) { [System.IO.File]::ReadAllText($stdoutPath) } else { '' }
        $stderr = if (Test-Path $stderrPath) { [System.IO.File]::ReadAllText($stderrPath) } else { '' }
        $parts = @()
        if (-not [string]::IsNullOrWhiteSpace($stdout)) { $parts += $stdout.TrimEnd() }
        if (-not [string]::IsNullOrWhiteSpace($stderr)) { $parts += $stderr.TrimEnd() }
        $output = ($parts -join [Environment]::NewLine)
        if ($Echo -and -not [string]::IsNullOrWhiteSpace($output)) { $output | Out-Host }
        return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $output }
    }
    finally {
        Remove-Item $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)][string]$CommandLine,
        [Parameter(Mandatory = $true)][string]$FailureMessage
    )
    $result = Invoke-CapturedCommand -CommandLine $CommandLine -WorkingDirectory $projectRoot -Echo
    if ($result.ExitCode -ne 0) { throw "$FailureMessage`n$($result.Output)" }
    return $result
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'flutter est introuvable dans PATH.' }
if (-not (Test-Path $cmdExe)) { throw "cmd.exe est introuvable : $cmdExe" }
$javaRuntime = Resolve-JavaRuntime
if (-not $javaRuntime) { throw 'Java est introuvable. Verifie le JDK affiche par flutter doctor -v.' }
if (-not (Test-Path $javaRuntime.Jarsigner)) { throw "jarsigner est introuvable : $($javaRuntime.Jarsigner)" }
Write-Host "JAVA_HOME temporaire : $($javaRuntime.JavaHome)" -ForegroundColor DarkGray
Write-Host "jarsigner detecte : $($javaRuntime.Jarsigner)" -ForegroundColor DarkGray

if (-not (Test-Path (Join-Path $projectRoot 'android\key.properties'))) { throw 'Signature release absente. Lance tool/release/setup_release_signing.ps1.' }
if (-not (Test-Path (Join-Path $projectRoot 'android\app\izytel-release-key.jks'))) { throw 'Keystore release absent : android/app/izytel-release-key.jks.' }

$pubspec = Get-Content (Join-Path $projectRoot 'pubspec.yaml') -Raw
if ($pubspec -notmatch [regex]::Escape("version: $version")) { throw "La version attendue est $version. Mets a jour ce script si tu prepares une version ulterieure." }
$gradle = Get-Content (Join-Path $projectRoot 'android\app\build.gradle.kts') -Raw
if ($gradle -notmatch [regex]::Escape("applicationId = `"$packageName`"")) { throw "applicationId doit etre $packageName." }

$localPropertiesPath = Join-Path $projectRoot 'android\local.properties'
if (-not (Test-Path $localPropertiesPath)) { throw 'android/local.properties est introuvable.' }
$localProperties = Get-Content $localPropertiesPath
$sdkLine = $localProperties | Where-Object { $_ -like 'sdk.dir=*' } | Select-Object -First 1
if (-not $sdkLine) { throw 'sdk.dir est absent de android/local.properties.' }
$sdkDir = ($sdkLine.Substring('sdk.dir='.Length) -replace '\\\\', '\')
$buildToolsRoot = Join-Path $sdkDir 'build-tools'
if (-not (Test-Path $buildToolsRoot)) { throw "Android build-tools introuvable : $buildToolsRoot" }
$buildTools = Get-ChildItem $buildToolsRoot -Directory | Sort-Object {
    try { [version]($_.Name -replace '[^0-9.].*$', '') } catch { [version]'0.0' }
} -Descending | Select-Object -First 1
if (-not $buildTools) { throw 'Aucune version Android build-tools installee.' }
$apksigner = Join-Path $buildTools.FullName 'apksigner.bat'
$aapt = Join-Path $buildTools.FullName 'aapt.exe'
if (-not (Test-Path $apksigner)) { throw "apksigner introuvable : $apksigner" }
if (-not (Test-Path $aapt)) { throw "aapt introuvable : $aapt" }

$previousJavaHome = $env:JAVA_HOME
$previousPath = $env:Path
$env:JAVA_HOME = $javaRuntime.JavaHome
$env:Path = "$($javaRuntime.JavaBin);$env:Path"

try {
    Invoke-CheckedCommand -CommandLine 'flutter clean' -FailureMessage 'flutter clean a echoue.' | Out-Null
    Invoke-CheckedCommand -CommandLine 'flutter pub get' -FailureMessage 'flutter pub get a echoue.' | Out-Null
    Invoke-CheckedCommand -CommandLine 'flutter analyze' -FailureMessage 'flutter analyze a echoue.' | Out-Null
    if (-not $SkipTests) {
        Invoke-CheckedCommand -CommandLine 'flutter test' -FailureMessage 'La suite de tests n est pas verte. Build release annule.' | Out-Null
    }
    Invoke-CheckedCommand -CommandLine 'flutter build apk --release' -FailureMessage 'flutter build apk --release a echoue.' | Out-Null
    Invoke-CheckedCommand -CommandLine 'flutter build appbundle --release' -FailureMessage 'flutter build appbundle --release a echoue.' | Out-Null

    $apk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
    $aab = Join-Path $projectRoot 'build\app\outputs\bundle\release\app-release.aab'
    if (-not (Test-Path $apk)) { throw 'APK release introuvable apres build.' }
    if (-not (Test-Path $aab)) { throw 'AAB release introuvable apres build.' }

    New-Item -ItemType Directory -Force -Path $distDir | Out-Null
    $apkOut = Join-Path $distDir "IzyTel-$artifactVersion-release.apk"
    $aabOut = Join-Path $distDir "IzyTel-$artifactVersion-release.aab"
    Copy-Item $apk $apkOut -Force
    Copy-Item $aab $aabOut -Force

    $apkSignaturePath = Join-Path $distDir "IzyTel-$artifactVersion-apk-signature.txt"
    $apkSignatureResult = Invoke-CapturedCommand -CommandLine "`"$apksigner`" verify --verbose --print-certs `"$apkOut`"" -WorkingDirectory $projectRoot
    $apkSignatureResult.Output | Set-Content $apkSignaturePath -Encoding ASCII
    if ($apkSignatureResult.ExitCode -ne 0) { throw "La verification apksigner a echoue. Voir $apkSignaturePath`n$($apkSignatureResult.Output)" }
    if ($apkSignatureResult.Output -match 'Android Debug') { throw 'SECURITE : APK release signe avec un certificat Android Debug.' }

    $aabSignaturePath = Join-Path $distDir "IzyTel-$artifactVersion-aab-signature.txt"
    $aabSignatureResult = Invoke-CapturedCommand -CommandLine "`"$($javaRuntime.Jarsigner)`" -verify -verbose -certs `"$aabOut`"" -WorkingDirectory $projectRoot
    $aabSignatureResult.Output | Set-Content $aabSignaturePath -Encoding ASCII
    if ($aabSignatureResult.ExitCode -ne 0) { throw "La verification jarsigner de l AAB a echoue. Voir $aabSignaturePath`n$($aabSignatureResult.Output)" }
    if ($aabSignatureResult.Output -match 'Android Debug') { throw 'SECURITE : AAB release signe avec un certificat Android Debug.' }
    if ($aabSignatureResult.Output -match '(?i)jar is unsigned|unsigned entries') { throw 'SECURITE : l AAB contient des entrees non signees ou est non signe.' }

    $badgingResult = Invoke-CapturedCommand -CommandLine "`"$aapt`" dump badging `"$apkOut`"" -WorkingDirectory $projectRoot
    if ($badgingResult.ExitCode -ne 0) { throw "aapt dump badging a echoue.`n$($badgingResult.Output)" }
    $packageLine = ($badgingResult.Output -split "`r?`n" | Where-Object { $_ -like 'package:*' } | Select-Object -First 1)
    if ($packageLine -notmatch "name='$([regex]::Escape($packageName))'") { throw "Le package reel de l APK n est pas $packageName. Ligne: $packageLine" }

    $apkHash = (Get-FileHash $apkOut -Algorithm SHA256).Hash
    $aabHash = (Get-FileHash $aabOut -Algorithm SHA256).Hash
    $builtAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    $manifestPath = Join-Path $distDir "IzyTel-$artifactVersion-release.sha256.txt"
    @(
        "IzyTel release $version"
        "package=$packageName"
        "built_at=$builtAt"
        "android_build_tools=$($buildTools.Name)"
        "apk_badging=$packageLine"
        "APK_SHA256=$apkHash  $(Split-Path $apkOut -Leaf)"
        "AAB_SHA256=$aabHash  $(Split-Path $aabOut -Leaf)"
    ) | Set-Content $manifestPath -Encoding ASCII

    Write-Host ''
    Write-Host 'Artifacts release generes et signatures verifiees :' -ForegroundColor Green
    Write-Host $apkOut
    Write-Host $aabOut
    Write-Host $manifestPath
    Write-Host $apkSignaturePath
    Write-Host $aabSignaturePath
}
finally {
    $env:JAVA_HOME = $previousJavaHome
    $env:Path = $previousPath
}
