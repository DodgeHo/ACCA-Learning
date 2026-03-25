param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('saa','sap')]
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

  flutter build apk --release
  if ($LASTEXITCODE -ne 0) {
    throw "flutter build apk failed"
  }

  $apk = Join-Path $root 'build/app/outputs/flutter-apk/app-release.apk'
  if (!(Test-Path $apk)) {
    throw "APK not found: $apk"
  }

  $outDir = Join-Path $root 'release/banks'
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
  $outApk = Join-Path $outDir "app-$VersionTag-$Bank.apk"
  Copy-Item -Path $apk -Destination $outApk -Force

  Write-Host "Built variant APK: $outApk"
}
finally {
  Pop-Location
}
