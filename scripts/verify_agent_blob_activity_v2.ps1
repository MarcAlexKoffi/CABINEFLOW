param(
  [string]$Root = "."
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path -LiteralPath $Root).Path

if (Test-Path -LiteralPath (Join-Path $projectRoot "payload")) {
  throw "Ancien dossier payload détecté à la racine. Supprime-le avant validation: Remove-Item -Recurse -Force .\payload"
}

function Read-ProjectFile([string]$RelativePath) {
  $path = Join-Path $projectRoot $RelativePath
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Fichier manquant: $RelativePath"
  }
  return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}

$rules = Read-ProjectFile "firestore.rules"
$profile = Read-ProjectFile "lib\features\agents\presentation\pages\agent_personal_profile_page.dart"
$media = Read-ProjectFile "lib\features\agents\data\repositories\firestore_agent_personal_media_repository.dart"
$activity = Read-ProjectFile "lib\features\agents\data\repositories\firestore_agent_activity_v2_repository.dart"
$activityModels = Read-ProjectFile "lib\features\agents\domain\models\agent_activity_v2_models.dart"
$dashboard = Read-ProjectFile "lib\features\agents\presentation\pages\agent_activity_v2_dashboard_page.dart"
$adminProfile = Read-ProjectFile "lib\features\agents\presentation\pages\admin_agent_profile_activity_page.dart"
$adminDetail = Read-ProjectFile "lib\features\agents\presentation\pages\agent_detail_page.dart"

$checks = @(
  @{ Name = "Blob Firestore"; Ok = $media.Contains("Blob(media.bytes)") },
  @{ Name = "Avatar <= 250 Ko"; Ok = $media.Contains("avatarMaxBytes = 250000") },
  @{ Name = "Pièce <= 850 Ko"; Ok = $media.Contains("identityMaxBytes = 850000") },
  @{ Name = "Signature PDF contrôlée"; Ok = ($media.Contains("bytes[0] == 0x25") -and $media.Contains("bytes[3] == 0x46")) },
  @{ Name = "Aucun API Storage dans profil"; Ok = (-not $profile.Contains("FirebaseStorage") -and -not $profile.Contains("firebase_storage") -and -not $profile.Contains("putData(") -and -not $profile.Contains("getDownloadURL(")) },
  @{ Name = "Règles médias"; Ok = $rules.Contains("match /agentPersonalMedia/{agentId}/items/{kind}") },
  @{ Name = "Lecture mouvements propre Agent"; Ok = $rules.Contains("resource.data.agentId == request.auth.uid") },
  @{ Name = "Activité sans agentActivities"; Ok = (-not $activity.Contains(".collection('agentActivities')")) },
  @{ Name = "Activité lecture seule"; Ok = (-not $activity.Contains("WriteBatch") -and -not $activity.Contains("runTransaction") -and -not $activity.Contains("FieldValue.serverTimestamp") -and -not $activity.Contains(".update(") -and -not $activity.Contains(".delete(")) },
  @{ Name = "Activité commissions"; Ok = ($activity.Contains(".collection('commissions')") -and $activity.Contains(".collection('commissionAccounts')") -and $activity.Contains(".collection('commissionPayouts')")) },
  @{ Name = "Activité capacités"; Ok = $activity.Contains(".collection('agentProfiles')") },
  @{ Name = "Activité signalements"; Ok = $activity.Contains(".collection('agentIssues')") },
  @{ Name = "Historique complet commandes"; Ok = $dashboard.Contains("historique complet") },
  @{ Name = "Completed direct + compat legacy"; Ok = ($activityModels.Contains("status == 'completed'") -and $activityModels.Contains("status == 'awaitingCustomerConfirmation'")) },
  @{ Name = "Admin voit Blob et activité"; Ok = ($adminProfile.Contains("AgentPersonalMediaKind.avatar") -and $adminProfile.Contains("AgentPersonalMediaKind.identity") -and $adminProfile.Contains("AgentActivityV2DashboardPage")) },
  @{ Name = "Accès Admin branché à la fiche Agent"; Ok = $adminDetail.Contains("AdminAgentProfileActivityPage(") },
  @{ Name = "Vérification Admin exige la pièce"; Ok = $rules.Contains("adminAgentVerificationHasRequiredIdentity(agentId)") },
  @{ Name = "9E préservé"; Ok = $rules.Contains("match /agentProfiles/{agentId}") },
  @{ Name = "Commandes préservées"; Ok = $rules.Contains("match /orders/{orderId}") },
  @{ Name = "Affectations préservées"; Ok = $rules.Contains("match /orderAssignments/{assignmentId}") },
  @{ Name = "Commissions préservées"; Ok = $rules.Contains("match /commissions/{commissionId}") },
  @{ Name = "Compte commissions préservé"; Ok = $rules.Contains("match /commissionAccounts/{accountId}") },
  @{ Name = "Versements préservés"; Ok = $rules.Contains("match /commissionPayouts/{payoutId}") },
  @{ Name = "Signalements préservés"; Ok = $rules.Contains("match /agentIssues/{issueId}") }
)

$failed = @()
foreach ($check in $checks) {
  $status = if ($check.Ok) { "OK" } else { "ECHEC" }
  Write-Host ("[{0}] {1}" -f $status, $check.Name)
  if (-not $check.Ok) { $failed += $check.Name }
}

if ($failed.Count -gt 0) {
  throw "Vérification B2+C échouée: $($failed -join ', ')"
}

Write-Host "Vérification structurelle B2+C réussie."
