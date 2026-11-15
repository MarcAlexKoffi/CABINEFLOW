$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$fontRoot = Join-Path $projectRoot 'scratch/ussd_reprise_visual'
New-Item -ItemType Directory -Path $fontRoot -Force | Out-Null
# Content hashes used by the installed Google Fonts Manrope descriptor.
$fonts = @{
    'Manrope-Regular.ttf' = '1ddeeeff9fe3d294f709f2239557278930f56dab89db1fe535dc5c35cd67e0ee'
    'acdd0ae608f0e024750c98bb1c4e76c13e31ad2b848eb8da7fcd783c051abafa.ttf' = 'acdd0ae608f0e024750c98bb1c4e76c13e31ad2b848eb8da7fcd783c051abafa'
    '8791ca409cf36b8b2842e40b6b1cd5b42cca064b4fdf24e30f5611536793429d.ttf' = '8791ca409cf36b8b2842e40b6b1cd5b42cca064b4fdf24e30f5611536793429d'
    'e7793683898d8a0e4c97ec50116fc021d053f2f72113982076a50a9048f101b5.ttf' = 'e7793683898d8a0e4c97ec50116fc021d053f2f72113982076a50a9048f101b5'
    '6b753fbbbefcdfd17909197147c199d6ebc1cd79742e853bc1e732bc9f49831b.ttf' = '6b753fbbbefcdfd17909197147c199d6ebc1cd79742e853bc1e732bc9f49831b'
}
foreach ($font in $fonts.GetEnumerator()) {
    $target = Join-Path $fontRoot $font.Key
    if (!(Test-Path -LiteralPath $target)) {
        Invoke-WebRequest -Uri "https://fonts.gstatic.com/s/a/$($font.Value).ttf" -OutFile $target
    }
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $font.Value) {
        throw "Unexpected Manrope font contents: $($font.Key)"
    }
}
Write-Output 'Five Manrope font fixtures verified.'
