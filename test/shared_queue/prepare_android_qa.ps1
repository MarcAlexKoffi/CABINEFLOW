$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'prepare_visual_qa.ps1')
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$qaRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'scratch/shared_queue_android_qa'))
if (!$qaRoot.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'QA target is outside the workspace' }
if (!(Test-Path -LiteralPath (Join-Path $qaRoot 'pubspec.yaml'))) {
    flutter create --empty --platforms android --org com.izytel.qa --project-name shared_queue_qa --no-pub $qaRoot
    if ($LASTEXITCODE -ne 0) { throw 'QA shell creation failed' }
}
$spec = @'
name: shared_queue_qa
publish_to: none
environment:
  sdk: ^3.12.2
dependencies:
  flutter:
    sdk: flutter
  cabine_flow:
    path: ../..
  google_fonts: ^6.3.0
  http: 1.6.0
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/brands/operators/
    - assets/qa_fonts/
'@
[IO.File]::WriteAllText((Join-Path $qaRoot 'pubspec.yaml'), $spec, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $qaRoot 'analysis_options.yaml'), "analyzer:`n  exclude:`n    - build/**`n", [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $projectRoot 'pubspec.lock') -Destination (Join-Path $qaRoot 'pubspec.lock') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets') -Destination $qaRoot -Recurse -Force
$fontRoot = Join-Path $qaRoot 'assets/qa_fonts'
New-Item -ItemType Directory -Path $fontRoot -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'scratch/ussd_reprise_visual') -Filter '*.ttf' -File | Copy-Item -Destination $fontRoot -Force
$testRoot = Join-Path $qaRoot 'integration_test'
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'device_scenarios.dart.template') -Destination (Join-Path $testRoot 'shared_queue_test.dart') -Force
Push-Location $qaRoot
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'QA dependencies could not be resolved' }
} finally { Pop-Location }
Write-Output "QA shell ready at $qaRoot (com.izytel.qa.shared_queue_qa; synthetic repositories only)."
