param(
    [switch]$ForceProperties
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$androidDir = Join-Path $projectRoot 'android'
$keystorePath = Join-Path $androidDir 'app\izytel-release-key.jks'
$keyPropertiesPath = Join-Path $androidDir 'key.properties'
$keyAlias = 'izytel-release'

function Resolve-JavaTool {
    param([Parameter(Mandatory = $true)][string]$ToolName)

    $command = Get-Command $ToolName -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $exeName = if ($ToolName.EndsWith('.exe')) { $ToolName } else { "$ToolName.exe" }
    $candidates = New-Object System.Collections.Generic.List[string]

    foreach ($javaHomeCandidate in @($env:JAVA_HOME, $env:JDK_HOME, $env:ANDROID_STUDIO_JDK)) {
        if (-not [string]::IsNullOrWhiteSpace($javaHomeCandidate)) {
            $candidates.Add((Join-Path $javaHomeCandidate "bin\$exeName"))
        }
    }

    if (Get-Command flutter -ErrorAction SilentlyContinue) {
        try {
            $doctor = (& flutter doctor -v 2>&1 | Out-String)
            $match = [regex]::Match($doctor, '(?im)^\s*[•\-]?\s*Java binary at:\s*(.+?java(?:\.exe)?)\s*$')
            if ($match.Success) {
                $javaPath = $match.Groups[1].Value.Trim().Trim('"')
                $javaBin = Split-Path $javaPath -Parent
                $candidates.Add((Join-Path $javaBin $exeName))
            }
        } catch {
            # Continue with well-known Android Studio paths below.
        }
    }

    $programFilesX86 = ${env:ProgramFiles(x86)}
    foreach ($candidate in @(
        (Join-Path $env:ProgramFiles "Android\Android Studio\jbr\bin\$exeName"),
        (Join-Path $env:ProgramFiles "Android\Android Studio\jre\bin\$exeName"),
        $(if ($programFilesX86) { Join-Path $programFilesX86 "Android\Android Studio\jbr\bin\$exeName" }),
        $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "Programs\Android Studio\jbr\bin\$exeName" })
    )) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            $candidates.Add($candidate)
        }
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}

$keytool = Resolve-JavaTool 'keytool'
if (-not $keytool) {
    throw @'
keytool est introuvable. Flutter peut utiliser un JDK Android Studio sans que son dossier bin soit dans PATH.
Execute d abord :
  flutter doctor -v | Select-String "Java binary at"
Puis verifie que keytool.exe se trouve dans le meme dossier bin que java.exe.
'@
}

Write-Host "keytool detecte : $keytool" -ForegroundColor DarkGray

if (-not (Test-Path $keystorePath)) {
    Write-Host ''
    Write-Host 'Creation de la cle officielle IzyTel.' -ForegroundColor Cyan
    Write-Host 'IMPORTANT : conserve cette cle et ses mots de passe. Sans elle, une future mise a jour signee avec cette cle sera impossible.' -ForegroundColor Yellow
    Write-Host 'keytool va demander le mot de passe et les informations du certificat. Utilise des mots de passe ASCII robustes.' -ForegroundColor Yellow
    Write-Host ''

    & $keytool -genkeypair -v `
        -keystore $keystorePath `
        -keyalg RSA `
        -keysize 4096 `
        -validity 10000 `
        -alias $keyAlias

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $keystorePath)) {
        throw 'La creation du keystore IzyTel a echoue.'
    }
} else {
    Write-Host "Keystore existant conserve : $keystorePath" -ForegroundColor Green
}

if ((Test-Path $keyPropertiesPath) -and -not $ForceProperties) {
    Write-Host "android/key.properties existe deja. Aucun ecrasement." -ForegroundColor Green
} else {
    Write-Host ''
    Write-Host 'Renseigne maintenant les mots de passe utilises avec keytool.' -ForegroundColor Cyan
    $storeSecure = Read-Host 'Mot de passe du keystore' -AsSecureString
    $keySecure = Read-Host 'Mot de passe de la cle (si identique, saisis le meme)' -AsSecureString

    $storePtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storeSecure)
    $keyPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keySecure)
    try {
        $storePassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($storePtr)
        $keyPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPtr)
        if ([string]::IsNullOrWhiteSpace($storePassword) -or [string]::IsNullOrWhiteSpace($keyPassword)) {
            throw 'Les mots de passe ne peuvent pas etre vides.'
        }

        $content = @(
            "storePassword=$storePassword"
            "keyPassword=$keyPassword"
            "keyAlias=$keyAlias"
            'storeFile=app/izytel-release-key.jks'
        ) -join "`n"

        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($keyPropertiesPath, $content + "`n", $utf8NoBom)
    }
    finally {
        if ($storePtr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($storePtr) }
        if ($keyPtr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPtr) }
        $storePassword = $null
        $keyPassword = $null
    }

    Write-Host "Fichier local cree : $keyPropertiesPath" -ForegroundColor Green
}

$gitignorePath = Join-Path $androidDir '.gitignore'
if (-not (Test-Path $gitignorePath)) {
    throw 'android/.gitignore est introuvable.'
}
$gitignore = Get-Content $gitignorePath -Raw
if ($gitignore -notmatch '(?m)^key\.properties\s*$' -or $gitignore -notmatch '\*\*/\*\.jks') {
    throw 'android/.gitignore ne protege pas correctement key.properties et les .jks.'
}

Write-Host ''
Write-Host 'Signature locale preparee.' -ForegroundColor Green
Write-Host 'Ne partage jamais android/key.properties ni android/app/izytel-release-key.jks.' -ForegroundColor Yellow
Write-Host 'Sauvegarde le .jks et ses mots de passe dans au moins deux emplacements securises distincts.' -ForegroundColor Yellow
