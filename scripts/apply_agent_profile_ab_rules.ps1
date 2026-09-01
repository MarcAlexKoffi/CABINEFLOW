param(
  [string]$RulesPath = "firestore.rules"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $RulesPath)) {
  throw "Fichier introuvable: $RulesPath"
}

$content = Get-Content -LiteralPath $RulesPath -Raw -Encoding UTF8
$original = $content
# A - Une réussite Agent clôture directement la commande. Les anciennes
# awaitingCustomerConfirmation restent supportées en lecture/compatibilité.
$oldSuccess = "request.resource.data.status == 'awaitingCustomerConfirmation'"
$newSuccess = "request.resource.data.status == 'completed'"
if ($content.Contains($oldSuccess)) {
  $content = $content.Replace($oldSuccess, $newSuccess)
} elseif (-not $content.Contains($newSuccess)) {
  throw "Transition de réussite Agent introuvable."
}

$oldAssignmentCompletion = "orderAfter.status in ['awaitingCustomerConfirmation', 'failed']"
$newAssignmentCompletion = "orderAfter.status in ['completed', 'awaitingCustomerConfirmation', 'failed']"
if ($content.Contains($oldAssignmentCompletion)) {
  $content = $content.Replace($oldAssignmentCompletion, $newAssignmentCompletion)
} elseif (-not $content.Contains($newAssignmentCompletion)) {
  throw "Validation de clôture orderAssignments introuvable."
}

$oldOrderSuccessEvidence = "&& order.status == 'awaitingCustomerConfirmation'"
$newOrderSuccessEvidence = "&& order.status in ['completed', 'awaitingCustomerConfirmation']"
if ($content.Contains($oldOrderSuccessEvidence)) {
  $content = $content.Replace($oldOrderSuccessEvidence, $newOrderSuccessEvidence)
} elseif (-not $content.Contains($newOrderSuccessEvidence)) {
  throw "Validations commission/mouvement réseau introuvables."
}

# B - Profil personnel Agent. Insertion strictement additive avant les règles
# zones afin de ne pas modifier 9E, les affectations, les paiements ou finances.
if ($content -notmatch "function hasValidAgentPersonalProfileValues\(agentId\)") {
  $anchor = "    function hasValidZoneKeys() {"
  if (-not $content.Contains($anchor)) {
    throw "Point d'insertion des fonctions Profil Agent introuvable."
  }

  $functions = @'
    // AGENT PROFILE V2 A+B - identity profile + direct completion
    function hasValidAgentPersonalProfileValues(agentId) {
      return request.resource.data.keys().hasOnly([
          'schemaVersion',
          'userId',
          'firstName',
          'lastName',
          'dateOfBirth',
          'address',
          'city',
          'contact1',
          'contact2',
          'emergencyContactName',
          'emergencyContactPhone',
          'identityDocumentType',
          'identityDocumentNumber',
          'avatarStoragePath',
          'identityDocumentStoragePath',
          'identityDocumentFileName',
          'identityDocumentMimeType',
          'verificationStatus',
          'verificationNote',
          'createdAt',
          'updatedAt'
        ])
        && request.resource.data.schemaVersion == 1
        && request.resource.data.userId == agentId
        && request.resource.data.firstName is string
        && request.resource.data.firstName.size() >= 2
        && request.resource.data.firstName.size() <= 80
        && request.resource.data.lastName is string
        && request.resource.data.lastName.size() >= 2
        && request.resource.data.lastName.size() <= 80
        && request.resource.data.dateOfBirth is timestamp
        && request.resource.data.address is string
        && request.resource.data.address.size() >= 3
        && request.resource.data.address.size() <= 200
        && request.resource.data.city is string
        && request.resource.data.city.size() >= 2
        && request.resource.data.city.size() <= 100
        && request.resource.data.contact1 is string
        && request.resource.data.contact1.size() >= 8
        && request.resource.data.contact1.size() <= 30
        && request.resource.data.contact2 is string
        && request.resource.data.contact2.size() <= 30
        && request.resource.data.emergencyContactName is string
        && request.resource.data.emergencyContactName.size() <= 100
        && request.resource.data.emergencyContactPhone is string
        && request.resource.data.emergencyContactPhone.size() <= 30
        && request.resource.data.identityDocumentType in [
          'nationalId',
          'passport',
          'drivingLicense',
          'residencePermit',
          'other'
        ]
        && request.resource.data.identityDocumentNumber is string
        && request.resource.data.identityDocumentNumber.size() <= 80
        && (
          request.resource.data.avatarStoragePath == null
          || request.resource.data.avatarStoragePath
            == 'agent_profiles/' + agentId + '/avatar/profile'
        )
        && (
          request.resource.data.identityDocumentStoragePath == null
          || request.resource.data.identityDocumentStoragePath
            == 'agent_profiles/' + agentId + '/identity/document'
        )
        && (
          request.resource.data.identityDocumentFileName == null
          || (
            request.resource.data.identityDocumentFileName is string
            && request.resource.data.identityDocumentFileName.size() <= 255
          )
        )
        && (
          request.resource.data.identityDocumentMimeType == null
          || request.resource.data.identityDocumentMimeType == 'application/pdf'
          || request.resource.data.identityDocumentMimeType.matches('^image/.*$')
        )
        && request.resource.data.verificationStatus in [
          'incomplete',
          'pendingReview',
          'verified',
          'needsCorrection'
        ]
        && (
          request.resource.data.verificationNote == null
          || (
            request.resource.data.verificationNote is string
            && request.resource.data.verificationNote.size() <= 500
          )
        )
        && request.resource.data.createdAt is timestamp
        && request.resource.data.updatedAt is timestamp;
    }

    function agentPersonalIdentityCoreIsUnchanged() {
      return request.resource.data.firstName == resource.data.firstName
        && request.resource.data.lastName == resource.data.lastName
        && request.resource.data.dateOfBirth == resource.data.dateOfBirth
        && request.resource.data.identityDocumentType == resource.data.identityDocumentType
        && request.resource.data.identityDocumentNumber == resource.data.identityDocumentNumber
        && request.resource.data.avatarStoragePath == resource.data.avatarStoragePath
        && request.resource.data.identityDocumentStoragePath
          == resource.data.identityDocumentStoragePath
        && request.resource.data.identityDocumentFileName
          == resource.data.identityDocumentFileName
        && request.resource.data.identityDocumentMimeType
          == resource.data.identityDocumentMimeType;
    }

    function isValidAgentPersonalProfileCreation(agentId) {
      return isAgent()
        && request.auth.uid == agentId
        && hasValidAgentPersonalProfileValues(agentId)
        && request.resource.data.verificationStatus in [
          'incomplete',
          'pendingReview'
        ]
        && request.resource.data.verificationNote == null
        && request.resource.data.createdAt == request.time
        && request.resource.data.updatedAt == request.time;
    }

    function isValidAgentPersonalProfileUpdate(agentId) {
      return isAgent()
        && request.auth.uid == agentId
        && hasValidAgentPersonalProfileValues(agentId)
        && request.resource.data.userId == resource.data.userId
        && request.resource.data.createdAt == resource.data.createdAt
        && request.resource.data.updatedAt == request.time
        && (
          (
            request.resource.data.verificationStatus in [
              'incomplete',
              'pendingReview'
            ]
            && request.resource.data.verificationNote == null
          )
          || (
            resource.data.verificationStatus == 'verified'
            && request.resource.data.verificationStatus == 'verified'
            && agentPersonalIdentityCoreIsUnchanged()
            && request.resource.data.verificationNote
              == resource.data.verificationNote
          )
        );
    }

    function isValidAdminAgentPersonalProfileVerification(agentId) {
      return isAdmin()
        && hasValidAgentPersonalProfileValues(agentId)
        && request.resource.data.userId == resource.data.userId
        && request.resource.data.createdAt == resource.data.createdAt
        && request.resource.data.diff(resource.data).affectedKeys().hasOnly([
          'verificationStatus',
          'verificationNote',
          'updatedAt'
        ])
        && request.resource.data.updatedAt == request.time;
    }

    function isValidAgentOwnUserContactUpdate(userId) {
      return isAgent()
        && request.auth.uid == userId
        && resource.data.role == 'agent'
        && request.resource.data.role == resource.data.role
        && request.resource.data.isActive == resource.data.isActive
        && request.resource.data.email == resource.data.email
        && request.resource.data.schemaVersion == resource.data.schemaVersion
        && request.resource.data.createdAt == resource.data.createdAt
        && request.resource.data.name is string
        && request.resource.data.name.size() >= 4
        && request.resource.data.name.size() <= 80
        && request.resource.data.phoneNumber is string
        && request.resource.data.phoneNumber.size() >= 8
        && request.resource.data.phoneNumber.size() <= 30
        && request.resource.data.diff(resource.data).affectedKeys().hasOnly([
          'name',
          'phoneNumber',
          'updatedAt'
        ])
        && request.resource.data.updatedAt == request.time;
    }

'@
  $content = $content.Replace($anchor, $functions + $anchor)
}

if ($content -notmatch "match /agentPersonalProfiles/\{agentId\}") {
  $anchor = "    match /agentProfiles/{agentId} {"
  if (-not $content.Contains($anchor)) {
    throw "Point d'insertion du match Profil Agent introuvable."
  }
  $profileMatch = @'
    match /agentPersonalProfiles/{agentId} {
      allow get: if isAdmin()
        || (isAgent() && request.auth.uid == agentId);
      allow list: if isAdmin();
      allow create: if isValidAgentPersonalProfileCreation(agentId);
      allow update: if isValidAgentPersonalProfileUpdate(agentId)
        || isValidAdminAgentPersonalProfileVerification(agentId);
      allow delete: if false;
    }

'@
  $content = $content.Replace($anchor, $profileMatch + $anchor)
}

if ($content -notmatch "isValidAgentOwnUserContactUpdate\(userId\)") {
  throw "La fonction d'auto-modification du contact Agent n'a pas été insérée."
}

$oldUserUpdate = "      allow update: if isValidAdminUserUpdate(userId);"
$newUserUpdate = "      allow update: if isValidAdminUserUpdate(userId)`r`n        || isValidAgentOwnUserContactUpdate(userId);"
if ($content.Contains($oldUserUpdate)) {
  $content = $content.Replace($oldUserUpdate, $newUserUpdate)
} elseif ($content -notmatch "allow update: if isValidAdminUserUpdate\(userId\)\s*\r?\n\s*\|\| isValidAgentOwnUserContactUpdate\(userId\);") {
  throw "Règle users/update inattendue. Aucun changement risqué n'a été appliqué."
}

if ($content -eq $original) {
  Write-Host "Aucun changement nécessaire: les règles A+B semblent déjà présentes." -ForegroundColor Yellow
  exit 0
}

$backup = "$RulesPath.pre_agent_profile_ab.bak"
if (-not (Test-Path -LiteralPath $backup)) {
  Copy-Item -LiteralPath $RulesPath -Destination $backup
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $RulesPath), $content, $utf8NoBom)
Write-Host "Règles A+B appliquées sans toucher aux autres flux." -ForegroundColor Green
Write-Host "Sauvegarde: $backup"
