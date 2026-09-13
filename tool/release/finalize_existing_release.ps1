$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$distDir = Join-Path $projectRoot 'dist'
$artifactVersion = '1.0.0_1'
$version = '1.0.0+1'
$packageName = 'com.izytel.app'
$expectedReleaseCertSha256 = '1731628C977D77351F6AF71FE5DB12FBF1CED28721C0D45DDB3CA8933AF6EA1E'

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
                Keytool = Join-Path $javaBin 'keytool.exe'
            }
        }
    }
    return $null
}

function Quote-NativeArgument {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)
    if ($Value -notmatch '[\s"]') { return $Value }
    # Windows CreateProcess quoting rules for paths/arguments containing spaces.
    $escaped = $Value -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Invoke-NativeCaptured {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory
    )

    if (-not (Test-Path $FilePath)) { throw "Executable introuvable : $FilePath" }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Arguments = (($Arguments | ForEach-Object { Quote-NativeArgument $_ }) -join ' ')

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    if (-not $process.Start()) { throw "Impossible de lancer : $FilePath" }
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    $parts = @()
    if (-not [string]::IsNullOrWhiteSpace($stdout)) { $parts += $stdout.TrimEnd() }
    if (-not [string]::IsNullOrWhiteSpace($stderr)) { $parts += $stderr.TrimEnd() }
    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        Output = ($parts -join [Environment]::NewLine)
    }
}


function Get-PemCertificateSha256 {
    param([Parameter(Mandatory = $true)][string]$Text)

    $pemMatch = [regex]::Match(
        $Text,
        '(?s)-----BEGIN CERTIFICATE-----\s*(?<body>[A-Za-z0-9+/=\r\n]+?)\s*-----END CERTIFICATE-----'
    )
    if (-not $pemMatch.Success) { return '' }

    $base64 = ($pemMatch.Groups['body'].Value -replace '\s', '')
    try {
        $certificateBytes = [Convert]::FromBase64String($base64)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            $hashBytes = $sha256.ComputeHash($certificateBytes)
            return (([BitConverter]::ToString($hashBytes)) -replace '-', '').ToUpperInvariant()
        } finally {
            $sha256.Dispose()
        }
    } catch {
        return ''
    }
}

function Normalize-Fingerprint {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    return (($Value -replace '[^0-9A-Fa-f]', '').ToUpperInvariant())
}

$apk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
$aab = Join-Path $projectRoot 'build\app\outputs\bundle\release\app-release.aab'
if (-not (Test-Path $apk)) { throw "APK release introuvable : $apk" }
if (-not (Test-Path $aab)) { throw "AAB release introuvable : $aab" }

$pubspec = Get-Content (Join-Path $projectRoot 'pubspec.yaml') -Raw
if ($pubspec -notmatch [regex]::Escape("version: $version")) { throw "Version inattendue. Phase 4 attend $version." }
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

$apksignerJar = Join-Path $buildTools.FullName 'lib\apksigner.jar'
$aapt = Join-Path $buildTools.FullName 'aapt.exe'
if (-not (Test-Path $apksignerJar)) { throw "apksigner.jar introuvable : $apksignerJar" }
if (-not (Test-Path $aapt)) { throw "aapt introuvable : $aapt" }

$javaRuntime = Resolve-JavaRuntime
if (-not $javaRuntime) { throw 'Java est introuvable.' }
if (-not (Test-Path $javaRuntime.Jarsigner)) { throw "jarsigner introuvable : $($javaRuntime.Jarsigner)" }
if (-not (Test-Path $javaRuntime.Keytool)) { throw "keytool introuvable : $($javaRuntime.Keytool)" }

Write-Host "APK trouve : $apk" -ForegroundColor DarkGray
Write-Host "AAB trouve : $aab" -ForegroundColor DarkGray
Write-Host "Android build-tools : $($buildTools.Name)" -ForegroundColor DarkGray
Write-Host "JAVA_HOME : $($javaRuntime.JavaHome)" -ForegroundColor DarkGray

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$apkOut = Join-Path $distDir "IzyTel-$artifactVersion-release.apk"
$aabOut = Join-Path $distDir "IzyTel-$artifactVersion-release.aab"
Copy-Item $apk $apkOut -Force
Copy-Item $aab $aabOut -Force

# APK: verify the APK, ask apksigner to emit the actual signer certificate as PEM,
# then calculate its SHA-256 from the DER certificate bytes. This deliberately avoids
# parsing apksigner's human-readable digest labels, whose wording/format can vary by version.
$apkSignaturePath = Join-Path $distDir "IzyTel-$artifactVersion-apk-signature.txt"
$apkSignatureResult = Invoke-NativeCaptured -FilePath $javaRuntime.Java -Arguments @(
    '-jar', $apksignerJar, 'verify', '--verbose', '--print-certs-pem', $apkOut
) -WorkingDirectory $projectRoot
$apkSignatureResult.Output | Set-Content $apkSignaturePath -Encoding ASCII
if ($apkSignatureResult.ExitCode -ne 0) { throw "Verification apksigner echouee. Voir $apkSignaturePath`n$($apkSignatureResult.Output)" }

$apkCertSha256 = Get-PemCertificateSha256 $apkSignatureResult.Output
if ([string]::IsNullOrWhiteSpace($apkCertSha256)) {
    throw "Impossible d extraire le certificat PEM de l APK. Voir $apkSignaturePath"
}
if ($apkCertSha256 -ne $expectedReleaseCertSha256) {
    throw "SECURITE : le certificat APK ne correspond pas a la cle officielle IzyTel. Attendu=$expectedReleaseCertSha256 Obtenu=$apkCertSha256"
}

# AAB: jarsigner verifies the JAR signature. keytool then emits the signer certificate
# in RFC/PEM form and we compute the SHA-256 ourselves, avoiding localized keytool labels.
$aabSignaturePath = Join-Path $distDir "IzyTel-$artifactVersion-aab-signature.txt"
$aabSignatureResult = Invoke-NativeCaptured -FilePath $javaRuntime.Jarsigner -Arguments @(
    '-verify', '-verbose', '-certs', $aabOut
) -WorkingDirectory $projectRoot
$aabSignatureResult.Output | Set-Content $aabSignaturePath -Encoding ASCII
if ($aabSignatureResult.ExitCode -ne 0) { throw "Verification jarsigner AAB echouee. Voir $aabSignaturePath`n$($aabSignatureResult.Output)" }
if ($aabSignatureResult.Output -match '(?i)jar is unsigned|unsigned entries') { throw 'SECURITE : AAB non signe ou entrees non signees.' }

$aabCertResult = Invoke-NativeCaptured -FilePath $javaRuntime.Keytool -Arguments @(
    '-printcert', '-rfc', '-jarfile', $aabOut
) -WorkingDirectory $projectRoot
if ($aabCertResult.ExitCode -ne 0) { throw "Lecture du certificat AAB impossible.`n$($aabCertResult.Output)" }
$aabCertSha256 = Get-PemCertificateSha256 $aabCertResult.Output
if ([string]::IsNullOrWhiteSpace($aabCertSha256)) {
    throw "Impossible d extraire le certificat PEM de l AAB.`n$($aabCertResult.Output)"
}
if ($aabCertSha256 -ne $expectedReleaseCertSha256) {
    throw "SECURITE : le certificat AAB ne correspond pas a la cle officielle IzyTel. Attendu=$expectedReleaseCertSha256 Obtenu=$aabCertSha256"
}

$badgingResult = Invoke-NativeCaptured -FilePath $aapt -Arguments @('dump', 'badging', $apkOut) -WorkingDirectory $projectRoot
if ($badgingResult.ExitCode -ne 0) { throw "aapt dump badging a echoue.`n$($badgingResult.Output)" }
$packageLine = ($badgingResult.Output -split "`r?`n" | Where-Object { $_ -like 'package:*' } | Select-Object -First 1)
if ($packageLine -notmatch "name='$([regex]::Escape($packageName))'") { throw "Package APK inattendu. Ligne : $packageLine" }

$apkHash = (Get-FileHash $apkOut -Algorithm SHA256).Hash
$aabHash = (Get-FileHash $aabOut -Algorithm SHA256).Hash
$builtAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
$manifestPath = Join-Path $distDir "IzyTel-$artifactVersion-release.sha256.txt"
@(
    "IzyTel release $version"
    "package=$packageName"
    "finalized_at=$builtAt"
    "android_build_tools=$($buildTools.Name)"
    "release_cert_sha256=$expectedReleaseCertSha256"
    "apk_badging=$packageLine"
    "APK_SHA256=$apkHash  $(Split-Path $apkOut -Leaf)"
    "AAB_SHA256=$aabHash  $(Split-Path $aabOut -Leaf)"
) | Set-Content $manifestPath -Encoding ASCII

Write-Host ''
Write-Host 'Release IzyTel finalisee sans reconstruire les binaires.' -ForegroundColor Green
Write-Host "APK : $apkOut"
Write-Host "AAB : $aabOut"
Write-Host "Manifest SHA256 : $manifestPath"
Write-Host "Signature APK : $apkSignaturePath"
Write-Host "Signature AAB : $aabSignaturePath"
Write-Host ''
Write-Host 'VERIFICATIONS : OK' -ForegroundColor Green
Write-Host "Package : $packageName" -ForegroundColor Green
Write-Host "Certificat release SHA256 : $expectedReleaseCertSha256" -ForegroundColor Green
Write-Host "APK SHA256 : $apkHash"
Write-Host "AAB SHA256 : $aabHash"
