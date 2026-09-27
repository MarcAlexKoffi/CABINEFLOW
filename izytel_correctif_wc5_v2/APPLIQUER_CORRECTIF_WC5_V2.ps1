$ErrorActionPreference = "Stop"

$ProjectRoot = (Get-Location).Path
$PatchRoot = Join-Path $PSScriptRoot "patch_files"

if (-not (Test-Path (Join-Path $ProjectRoot "pubspec.yaml"))) {
    throw "Lance ce script depuis la racine du projet cabine_flow (le dossier qui contient pubspec.yaml)."
}

if (-not (Test-Path $PatchRoot)) {
    throw "Le dossier patch_files est introuvable. Garde-le a cote de ce script."
}

Write-Host ""
Write-Host "=============================================="
Write-Host " IzyTel WC5 V2 - Application du correctif"
Write-Host "=============================================="
Write-Host ""

# 1. Remplacer les fichiers modifies.
Get-ChildItem -Path $PatchRoot -File -Recurse | ForEach-Object {
    $relative = $_.FullName.Substring($PatchRoot.Length).TrimStart('\','/')
    $destination = Join-Path $ProjectRoot $relative
    $parent = Split-Path $destination -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item $_.FullName $destination -Force
    Write-Host "[REMPLACE] $relative"
}

# 2. Supprimer les anciens elements exclusivement WhatsApp.
# customer_confirmation_page.dart NE doit PAS etre supprime : sa nouvelle
# version est maintenant basee sur le suivi + la messagerie IzyTel.
$obsolete = @(
    "assets\images\whatsapp_logo.png",
    "lib\backoffice\presentation\services\backoffice_whatsapp_service.dart",
    "lib\core\services\customer_support_whatsapp.dart",
    "lib\features\customer_order\presentation\widgets\customer_support_button.dart",
    "test\core\services\customer_support_whatsapp_test.dart",
    "test\regressions\phase2_web_navigation_whatsapp_buttons_contract_test.dart"
)

foreach ($relative in $obsolete) {
    $path = Join-Path $ProjectRoot $relative
    if (Test-Path $path) {
        Remove-Item $path -Force
        Write-Host "[SUPPRIME] $relative"
    } else {
        Write-Host "[DEJA ABSENT] $relative"
    }
}

Write-Host ""
Write-Host "Correctif WC5 V2 applique."
Write-Host "Tu peux maintenant lancer la campagne de tests fournie dans README_WC5_V2.txt."
Write-Host ""
