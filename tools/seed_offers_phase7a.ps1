param(
  [string]$ProjectId = "cabineflow-4bca7",
  [string]$ApiKey = "AIzaSyCHPb-T0WKYog7tXSmNRimKcQIXJ-mYAQU",
  [string]$SeedFile = (Join-Path $PSScriptRoot "offers_seed_phase7a.json")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $SeedFile)) {
  throw "Seed file not found: $SeedFile"
}

function New-StringValue([object]$Value) {
  return @{ stringValue = [string]$Value }
}

function New-NullableStringValue([object]$Value) {
  if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
    return @{ nullValue = $null }
  }

  return @{ stringValue = [string]$Value }
}

function New-StringArrayValue([object]$Items) {
  $values = @()

  if ($null -ne $Items) {
    foreach ($item in $Items) {
      $values += @{ stringValue = [string]$item }
    }
  }

  return @{ arrayValue = @{ values = $values } }
}

Write-Host "CabineFlow - Phase 7A offer seeding"
Write-Host "Project: $ProjectId"
Write-Host "Seed file: $SeedFile"
Write-Host ""
Write-Host "Use an active Firebase account whose users/<uid> document has role=admin."
Write-Host ""

$email = Read-Host "Firebase admin email"
$securePassword = Read-Host "Firebase admin password" -AsSecureString
$passwordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)

try {
  $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPtr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPtr)
}

$signInUri = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$ApiKey"
$signInBody = @{
  email = $email
  password = $password
  returnSecureToken = $true
} | ConvertTo-Json

try {
  $auth = Invoke-RestMethod `
    -Method Post `
    -Uri $signInUri `
    -ContentType "application/json; charset=utf-8" `
    -Body ([Text.Encoding]::UTF8.GetBytes($signInBody))
} finally {
  $password = $null
}

if ([string]::IsNullOrWhiteSpace($auth.idToken)) {
  throw "Firebase authentication did not return an ID token."
}

Write-Host "Authenticated UID: $($auth.localId)"

$offers = Get-Content $SeedFile -Raw -Encoding UTF8 | ConvertFrom-Json
$headers = @{ Authorization = "Bearer $($auth.idToken)" }
$created = 0
$failed = 0

foreach ($offer in $offers) {
  $now = [DateTime]::UtcNow.ToString("o")
  $documentId = [string]$offer.id
  $uri = "https://firestore.googleapis.com/v1/projects/$ProjectId/databases/(default)/documents/offers/$documentId"
  $createdAt = $now

  try {
    $existing = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers

    if ($null -ne $existing.fields.createdAt.timestampValue) {
      $createdAt = [string]$existing.fields.createdAt.timestampValue
    }
  } catch {
    # A missing document is expected on the first import.
  }

  $fields = @{
    schemaVersion = @{ integerValue = [string]$offer.schemaVersion }
    network = New-StringValue $offer.network
    service = New-StringValue $offer.service
    operationType = New-StringValue $offer.operationType
    title = New-StringValue $offer.title
    catalogLabel = New-StringValue $offer.catalogLabel
    description = New-NullableStringValue $offer.description
    sellingPrice = @{ integerValue = [string]$offer.sellingPrice }
    details = New-StringArrayValue $offer.details
    badgeLabel = New-NullableStringValue $offer.badgeLabel
    category = New-StringValue $offer.category
    validity = New-NullableStringValue $offer.validity
    volume = New-NullableStringValue $offer.volume
    minutes = New-NullableStringValue $offer.minutes
    sms = New-NullableStringValue $offer.sms
    eligibility = New-NullableStringValue $offer.eligibility
    isActive = @{ booleanValue = [bool]$offer.isActive }
    displayOrder = @{ integerValue = [string]$offer.displayOrder }
    createdAt = @{ timestampValue = $createdAt }
    updatedAt = @{ timestampValue = $now }
  }

  $body = @{ fields = $fields } | ConvertTo-Json -Depth 30

  try {
    Invoke-RestMethod `
      -Method Patch `
      -Uri $uri `
      -Headers $headers `
      -ContentType "application/json; charset=utf-8" `
      -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null

    $created++
    Write-Host "[OK] $documentId"
  } catch {
    $failed++
    Write-Host "[ERROR] $documentId" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
  }
}

Write-Host ""
Write-Host "Finished. Successful: $created - Failed: $failed"

if ($failed -gt 0) {
  throw "Some offers could not be written. Check that the new Firestore rules are published and that the account is an active admin."
}
