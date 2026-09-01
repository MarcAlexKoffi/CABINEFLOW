param(
  [string]$RulesPath = "firestore.rules"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $RulesPath)) {
  throw "Fichier introuvable: $RulesPath"
}

$content = Get-Content -LiteralPath $RulesPath -Raw -Encoding UTF8
$original = $content

if ($content -notmatch "function hasValidAgentPersonalProfileValues\(agentId\)") {
  throw "Baseline A+B absente: applique d'abord les règles agentPersonalProfiles validées."
}

if ($content -notmatch "function hasValidAgentPersonalMediaValues\(agentId, kind\)") {
  $anchor = "    function hasValidZoneKeys() {"
  if (-not $content.Contains($anchor)) {
    throw "Point d'insertion des fonctions B2 introuvable."
  }

  $functions = @'
    // B2 - médias privés Agent en Blob Firestore, sans Firebase Storage.
    // 250 Ko pour l'avatar; 850 Ko pour la pièce afin de garder une marge
    // confortable sous la limite de taille d'un document Firestore.
    function hasValidAgentPersonalMediaValues(agentId, kind) {
      return request.resource.data.keys().hasOnly([
          'schemaVersion',
          'agentId',
          'kind',
          'fileName',
          'mimeType',
          'contentBytes',
          'sizeBytes',
          'createdAt',
          'updatedAt'
        ])
        && request.resource.data.schemaVersion == 1
        && request.resource.data.agentId == agentId
        && request.resource.data.kind == kind
        && kind in ['avatar', 'identity']
        && request.resource.data.fileName is string
        && request.resource.data.fileName.size() >= 1
        && request.resource.data.fileName.size() <= 255
        && request.resource.data.mimeType is string
        && request.resource.data.contentBytes is bytes
        && request.resource.data.sizeBytes is int
        && request.resource.data.sizeBytes > 0
        && request.resource.data.sizeBytes
          == request.resource.data.contentBytes.size()
        && (
          (
            kind == 'avatar'
            && request.resource.data.mimeType == 'image/jpeg'
            && request.resource.data.sizeBytes <= 250000
          )
          || (
            kind == 'identity'
            && request.resource.data.mimeType in [
              'image/jpeg',
              'application/pdf'
            ]
            && request.resource.data.sizeBytes <= 850000
          )
        )
        && request.resource.data.createdAt is timestamp
        && request.resource.data.updatedAt is timestamp;
    }

    function agentCanWritePersonalMedia(agentId, kind) {
      let profileAfter = getAfter(
        /databases/$(database)/documents/agentPersonalProfiles/$(agentId)
      ).data;
      return isAgent()
        && request.auth.uid == agentId
        && profileAfter.userId == agentId
        // Après validation Admin, l'identité est figée. L'avatar reste modifiable.
        && (
          kind == 'avatar'
          || profileAfter.verificationStatus != 'verified'
        );
    }

    function isValidAgentPersonalMediaCreation(agentId, kind) {
      return agentCanWritePersonalMedia(agentId, kind)
        && hasValidAgentPersonalMediaValues(agentId, kind)
        && request.resource.data.createdAt == request.time
        && request.resource.data.updatedAt == request.time;
    }

    function isValidAgentPersonalMediaUpdate(agentId, kind) {
      return agentCanWritePersonalMedia(agentId, kind)
        && hasValidAgentPersonalMediaValues(agentId, kind)
        && request.resource.data.agentId == resource.data.agentId
        && request.resource.data.kind == resource.data.kind
        && request.resource.data.createdAt == resource.data.createdAt
        && request.resource.data.updatedAt == request.time;
    }

'@
  $content = $content.Replace($anchor, $functions + $anchor)
}


if ($content -notmatch "function adminAgentVerificationHasRequiredIdentity\(agentId\)") {
  $anchor = "    function hasValidZoneKeys() {"
  if (-not $content.Contains($anchor)) {
    throw "Point d'insertion du garde-fou de vérification B2 introuvable."
  }
  $verificationHelper = @'
    function adminAgentVerificationHasRequiredIdentity(agentId) {
      return request.resource.data.verificationStatus != 'verified'
        || exists(
          /databases/$(database)/documents/agentPersonalMedia/$(agentId)/items/identity
        );
    }

'@
  $content = $content.Replace($anchor, $verificationHelper + $anchor)
}

# Un profil ne peut être déclaré vérifié par l'Admin que si la pièce Blob existe.
if ($content -notmatch "isValidAdminAgentPersonalProfileVerification\(agentId\)[\s\S]{0,260}adminAgentVerificationHasRequiredIdentity\(agentId\)") {
  $pattern = "(?s)(function isValidAdminAgentPersonalProfileVerification\(agentId\)\s*\{\s*return isAdmin\(\))"
  if ($content -notmatch $pattern) {
    throw "Fonction de vérification Admin A+B introuvable; arrêt sans modification."
  }
  $replacement = '$1' + "`r`n        && adminAgentVerificationHasRequiredIdentity(agentId)"
  $content = [regex]::Replace(
    $content,
    $pattern,
    $replacement,
    1
  )
}

if ($content -notmatch "match /agentPersonalMedia/\{agentId\}/items/\{kind\}") {
  $anchor = "    match /agentPersonalProfiles/{agentId} {"
  if (-not $content.Contains($anchor)) {
    throw "Point d'insertion du match agentPersonalMedia introuvable."
  }
  $mediaMatch = @'
    match /agentPersonalMedia/{agentId}/items/{kind} {
      allow get: if isAdmin()
        || (isAgent() && request.auth.uid == agentId);
      allow list: if isAdmin()
        || (isAgent() && request.auth.uid == agentId);
      allow create: if isValidAgentPersonalMediaCreation(agentId, kind);
      allow update: if isValidAgentPersonalMediaUpdate(agentId, kind);
      allow delete: if false;
    }

'@
  $content = $content.Replace($anchor, $mediaMatch + $anchor)
}

# C - le tableau de bord Agent lit uniquement SES mouvements. Aucun droit
# d'écriture finance n'est élargi.
if ($content -notmatch "match /networkTransactions/\{transactionId\}[\s\S]{0,350}resource\.data\.agentId == request\.auth\.uid") {
  $pattern = "(?s)(match /networkTransactions/\{transactionId\}\s*\{\s*)allow get, list: if isAdmin\(\);"
  if ($content -notmatch $pattern) {
    throw "Bloc networkTransactions attendu introuvable; arrêt sans modification."
  }
  $replacement = @'
$1allow get, list: if isAdmin()
        || (
          isAgent()
          && resource.data.agentId == request.auth.uid
        );
'@
  $content = [regex]::Replace($content, $pattern, $replacement, 1)
}

# Garde-fous de non-régression : le patch doit retrouver les contrats critiques.
$required = @(
  "match /agentProfiles/{agentId}",
  "match /orders/{orderId}",
  "match /orderAssignments/{assignmentId}",
  "match /networkTransactions/{transactionId}",
  "match /commissions/{commissionId}",
  "match /commissionAccounts/{accountId}",
  "match /commissionPayouts/{payoutId}",
  "match /agentIssues/{issueId}",
  "match /agentPersonalProfiles/{agentId}",
  "match /agentPersonalMedia/{agentId}/items/{kind}"
)
foreach ($token in $required) {
  if (-not $content.Contains($token)) {
    throw "Garde-fou manquant après patch: $token"
  }
}

if ($content -ne $original) {
  $backup = "$RulesPath.pre_agent_blob_activity_v2.bak"
  Copy-Item -LiteralPath $RulesPath -Destination $backup -Force
  $resolvedRulesPath = (Resolve-Path -LiteralPath $RulesPath).Path
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($resolvedRulesPath, $content, $utf8NoBom)
  Write-Host "Règles B2+C appliquées de façon additive."
  Write-Host "Sauvegarde: $backup"
} else {
  Write-Host "Règles B2+C déjà présentes; aucune modification."
}
