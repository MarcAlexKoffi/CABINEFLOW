param([switch]$Apply)
$ErrorActionPreference = 'Stop'
$workspaceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$manifest = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'changes_manifest.json') | ConvertFrom-Json

function Resolve-WorkspaceFile([string]$relativePath) {
  $absolutePath = [IO.Path]::GetFullPath((Join-Path $workspaceRoot $relativePath))
  if (!$absolutePath.StartsWith($workspaceRoot + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase)) { throw 'Path outside workspace' }
  return $absolutePath
}

# Validate every file before changing anything. Later user edits are protected.
foreach ($entry in $manifest.modified) {
  $path = Resolve-WorkspaceFile $entry.path
  $backup = Resolve-WorkspaceFile $entry.backup
  if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry.afterSha256) {
    throw ('File changed since delivery: ' + $entry.path)
  }
  if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $entry.beforeSha256) {
    throw ('Original backup changed: ' + $entry.path)
  }
}
foreach ($entry in $manifest.created) {
  $path = Resolve-WorkspaceFile $entry.path
  if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry.sha256) {
    throw ('New file changed since delivery: ' + $entry.path)
  }
}

if (!$Apply) {
  Write-Output ('Verified: {0} original files to restore, {1} new files to remove.' -f
      $manifest.modified.Count, $manifest.created.Count)
  Write-Output 'Preview only. Use -Apply explicitly to restore this local change set.'
  return
}

foreach ($entry in $manifest.modified) {
  Copy-Item -LiteralPath (Resolve-WorkspaceFile $entry.backup) -Destination (Resolve-WorkspaceFile $entry.path)
}
foreach ($entry in $manifest.created) {
  Remove-Item -LiteralPath (Resolve-WorkspaceFile $entry.path)
}
Write-Output 'Local stabilization changes restored. Existing user changes and server state were not touched.'
