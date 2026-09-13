$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$androidDir = Join-Path $projectRoot 'android'
$appId = '1:542869507309:android:6719f71b043fae652f10e4'
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
            if ($match.Success) {
                $candidates.Add($match.Groups[1].Value.Trim().Trim('"'))
            }
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
            }
        }
    }
    return $null
}

function Invoke-CapturedCommand {
    param(
        [Parameter(Mandatory = $true)][string]$CommandLine,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory
    )

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
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
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            Output = ($parts -join [Environment]::NewLine)
        }
    }
    finally {
        Remove-Item $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path (Join-Path $androidDir 'key.properties'))) {
    throw 'android/key.properties est absent. Lance d abord tool/release/setup_release_signing.ps1.'
}
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    throw 'Firebase CLI est introuvable.'
}
if (-not (Test-Path $cmdExe)) {
    throw "cmd.exe est introuvable : $cmdExe"
}

$javaRuntime = Resolve-JavaRuntime
if (-not $javaRuntime) {
    throw 'Java est introuvable. Verifie le JDK affiche par flutter doctor -v.'
}

Write-Host "JAVA_HOME temporaire : $($javaRuntime.JavaHome)" -ForegroundColor DarkGray
$previousJavaHome = $env:JAVA_HOME
$previousPath = $env:Path
$env:JAVA_HOME = $javaRuntime.JavaHome
$env:Path = "$($javaRuntime.JavaBin);$env:Path"

try {
    # IMPORTANT: Gradle is executed through cmd.exe + Start-Process redirection.
    # This prevents Windows PowerShell 5.x from turning harmless native STDERR
    # warnings into NativeCommandError records before we can inspect the exit code.
    $gradleResult = Invoke-CapturedCommand -CommandLine 'gradlew.bat signingReport --console=plain' -WorkingDirectory $androidDir
    $report = $gradleResult.Output
    if ($gradleResult.ExitCode -ne 0) {
        throw "gradlew signingReport a echoue.`n$report"
    }

    $releaseMatch = [regex]::Match(
        $report,
        '(?s)Variant:\s*release\s+.*?SHA1:\s*([A-Fa-f0-9:]+).*?SHA-256:\s*([A-Fa-f0-9:]+)'
    )
    if (-not $releaseMatch.Success) {
        throw "Impossible d extraire SHA1/SHA-256 du certificat release.`n$report"
    }

    $sha1 = $releaseMatch.Groups[1].Value.ToUpperInvariant()
    $sha256 = $releaseMatch.Groups[2].Value.ToUpperInvariant()
    Write-Host "SHA1 release    : $sha1" -ForegroundColor Cyan
    Write-Host "SHA-256 release : $sha256" -ForegroundColor Cyan

    function Normalize-Sha([string]$value) {
        if ([string]::IsNullOrWhiteSpace($value)) { return '' }
        return (($value -replace '[^0-9A-Fa-f]', '').ToUpperInvariant())
    }

    function Read-FirebaseShaList {
        $result = Invoke-CapturedCommand -CommandLine "firebase apps:android:sha:list $appId" -WorkingDirectory $projectRoot
        if ($result.ExitCode -ne 0) {
            throw "Impossible de lire les empreintes Firebase.`n$($result.Output)"
        }
        return $result.Output
    }

    $sha1Normalized = Normalize-Sha $sha1
    $sha256Normalized = Normalize-Sha $sha256

    Write-Host 'Verification des empreintes deja declarees...' -ForegroundColor Cyan
    $shaList = Read-FirebaseShaList
    $firebaseHex = Normalize-Sha $shaList

    if ($firebaseHex -notlike "*$sha1Normalized*") {
        Write-Host 'Enregistrement SHA-1...' -ForegroundColor Cyan
        $sha1Result = Invoke-CapturedCommand -CommandLine "firebase apps:android:sha:create $appId $sha1" -WorkingDirectory $projectRoot
        if (-not [string]::IsNullOrWhiteSpace($sha1Result.Output)) { $sha1Result.Output | Out-Host }
        if ($sha1Result.ExitCode -ne 0) {
            Write-Warning 'La CLI a retourne un code non nul pour SHA-1. La verification finale determinera si l empreinte a tout de meme ete enregistree.'
        }
    } else {
        Write-Host 'SHA-1 deja presente dans Firebase. Aucun doublon cree.' -ForegroundColor DarkGray
    }

    if ($firebaseHex -notlike "*$sha256Normalized*") {
        Write-Host 'Enregistrement SHA-256...' -ForegroundColor Cyan
        $sha256Result = Invoke-CapturedCommand -CommandLine "firebase apps:android:sha:create $appId $sha256" -WorkingDirectory $projectRoot
        if (-not [string]::IsNullOrWhiteSpace($sha256Result.Output)) { $sha256Result.Output | Out-Host }
        if ($sha256Result.ExitCode -ne 0) {
            Write-Warning 'La CLI a retourne un code non nul pour SHA-256. La verification finale determinera si l empreinte a tout de meme ete enregistree.'
        }
    } else {
        Write-Host 'SHA-256 deja presente dans Firebase. Aucun doublon cree.' -ForegroundColor DarkGray
    }

    Write-Host 'Empreintes actuellement declarees :' -ForegroundColor Cyan
    $shaList = Read-FirebaseShaList
    if (-not [string]::IsNullOrWhiteSpace($shaList)) { $shaList | Out-Host }

    # Firebase CLI affiche actuellement les hashes en minuscules et sans ':'.
    # On normalise donc les deux cotes avant comparaison pour eviter les faux echecs.
    $firebaseHex = Normalize-Sha $shaList
    if ($firebaseHex -notlike "*$sha1Normalized*") {
        throw "SHA-1 release absente de Firebase. Attendue (normalisee): $sha1Normalized"
    }
    if ($firebaseHex -notlike "*$sha256Normalized*") {
        throw "SHA-256 release absente de Firebase. Attendue (normalisee): $sha256Normalized"
    }
    Write-Host ''
    Write-Host 'Empreintes Firebase release verifiees.' -ForegroundColor Green
}
finally {
    $env:JAVA_HOME = $previousJavaHome
    $env:Path = $previousPath
}
