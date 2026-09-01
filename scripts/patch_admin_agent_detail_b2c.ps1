param(
  [string]$Root = "."
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path -LiteralPath $Root).Path
$target = Join-Path $projectRoot "lib\features\agents\presentation\pages\agent_detail_page.dart"

if (-not (Test-Path -LiteralPath $target)) {
  throw "Fichier Admin introuvable: lib\features\agents\presentation\pages\agent_detail_page.dart"
}

$content = Get-Content -LiteralPath $target -Raw -Encoding UTF8

if ($content.Contains("AdminAgentProfileActivityPage(")) {
  Write-Host "Accès Admin B2+C déjà présent dans agent_detail_page.dart."
  exit 0
}

$requiredTokens = @(
  "class AgentDetailPage"
)
foreach ($token in $requiredTokens) {
  if (-not $content.Contains($token)) {
    throw "Structure AgentDetailPage non reconnue ($token absent). Aucune modification effectuée."
  }
}

$importLine = "import 'package:cabine_flow/features/agents/presentation/pages/admin_agent_profile_activity_page.dart';"
if (-not $content.Contains($importLine)) {
  $imports = [regex]::Matches($content, "(?m)^import .+;\r?$")
  if ($imports.Count -eq 0) {
    throw "Imports Dart introuvables dans agent_detail_page.dart. Aucune modification effectuée."
  }
  $lastImport = $imports[$imports.Count - 1]
  $insertAt = $lastImport.Index + $lastImport.Length
  $content = $content.Insert($insertAt, "`r`n$importLine")
}

$stateMarker = "class _AgentDetailPageState"
$stateStart = $content.IndexOf($stateMarker)
if ($stateStart -lt 0) {
  throw "Etat AgentDetailPage introuvable. Aucune modification effectuee."
}

$nextClass = $content.IndexOf("`nclass ", $stateStart + $stateMarker.Length)
if ($nextClass -lt 0) {
  $nextClass = $content.Length
}
$stateLength = $nextClass - $stateStart
$stateContent = $content.Substring($stateStart, $stateLength)

$scaffoldMatches = [regex]::Matches($stateContent, "return\s+Scaffold\(")
if ($scaffoldMatches.Count -ne 1) {
  throw "Impossible d'identifier de facon sure le Scaffold de _AgentDetailPageState. Aucune modification effectuee."
}

if ($stateContent.Contains("floatingActionButton:")) {
  throw "La fiche Agent possede deja un floatingActionButton. Patch automatique arrete pour ne pas ecraser l'UI existante."
}

$openDetail = @'
return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AdminAgentProfileActivityPage(
                agentId: widget.agent.userId,
                agentName: widget.agent.name,
              ),
            ),
          );
        },
        label: const Text('Identité & activité'),
      ),
'@

$scaffoldMatch = $scaffoldMatches[0]
$absoluteScaffoldIndex = $stateStart + $scaffoldMatch.Index
$content = $content.Remove($absoluteScaffoldIndex, $scaffoldMatch.Length)
$content = $content.Insert($absoluteScaffoldIndex, $openDetail)

if (-not $content.Contains("AdminAgentProfileActivityPage(")) {
  throw "Injection Admin B2+C non confirmée. Aucune écriture effectuée."
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $projectRoot ".izytel_backups\agent_detail_b2c_$timestamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir "agent_detail_page.dart") -Force

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($target, $content, $utf8NoBom)

Write-Host "Accès Admin B2+C ajouté dans AgentDetailPage."
Write-Host "Sauvegarde: $backupDir"
