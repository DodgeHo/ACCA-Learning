param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('saa','sap','ispm','pm','tx','fr','aa','fm','sbl','sbr','afm','apm','aaa')]
  [string]$Bank,

  [string]$VersionTag = '0.2.0'
)

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $root

try {
  & (Join-Path $PSScriptRoot 'select_question_bank.ps1') -Bank $Bank

  flutter pub get
  if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get failed"
  }

  flutter build apk --release --flavor $Bank
  if ($LASTEXITCODE -ne 0) {
    throw "flutter build apk failed"
  }

  $apkCandidates = @(
    (Join-Path $root "build/app/outputs/flutter-apk/app-$Bank-release.apk"),
    (Join-Path $root 'build/app/outputs/flutter-apk/app-release.apk')
  )
  $apk = $apkCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $apk) {
    throw "APK not found for flavor '$Bank'. Checked: $($apkCandidates -join ', ')"
  }

  $outDir = Join-Path $root 'release/banks'
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
  $artifactBankTag = if ($Bank -eq 'ispm') { 'ispm-experimental' } else { $Bank }
  $outApk = Join-Path $outDir "app-$VersionTag-$artifactBankTag.apk"
  Copy-Item -Path $apk -Destination $outApk -Force

  Write-Host "Built variant APK: $outApk"
}
finally {
  Pop-Location
}
