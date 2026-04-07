param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('pm','tx','fr','aa','fm','sbl','sbr','afm','apm','aaa','saa','sap','ispm')]
  [string]$Bank,

  [string]$VersionTag = '0.3.0',
  [switch]$NoAndroid,
  [switch]$NoWindows,
  [switch]$NoWeb
)

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $root

try {
  & (Join-Path $PSScriptRoot 'select_question_bank.ps1') -Bank $Bank

  flutter pub get
  if ($LASTEXITCODE -ne 0) {
    throw 'flutter pub get failed'
  }

  $outDir = Join-Path $root "release/$VersionTag-$Bank"
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null

  if (-not $NoAndroid) {
    flutter build apk --release --flavor $Bank
    if ($LASTEXITCODE -ne 0) {
      throw 'flutter build apk failed'
    }

    $apkCandidates = @(
      (Join-Path $root "build/app/outputs/flutter-apk/app-$Bank-release.apk"),
      (Join-Path $root 'build/app/outputs/flutter-apk/app-release.apk')
    )
    $apk = $apkCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $apk) {
      throw "APK not found for '$Bank'"
    }
    Copy-Item $apk (Join-Path $outDir "acca-$Bank-$VersionTag-android.apk") -Force
  }

  if (-not $NoWindows) {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
      throw 'flutter build windows failed'
    }

    $winSrc = Join-Path $root 'build/windows/x64/runner/Release'
    $winZip = Join-Path $outDir "acca-$Bank-$VersionTag-windows-x64.zip"
    if (Test-Path $winZip) {
      Remove-Item $winZip -Force
    }
    Compress-Archive -Path (Join-Path $winSrc '*') -DestinationPath $winZip
  }

  if (-not $NoWeb) {
    flutter build web --release --base-href "/$Bank/"
    if ($LASTEXITCODE -ne 0) {
      throw 'flutter build web failed'
    }

    $webSrc = Join-Path $root 'build/web'
    $webZip = Join-Path $outDir "acca-$Bank-$VersionTag-web.zip"
    if (Test-Path $webZip) {
      Remove-Item $webZip -Force
    }
    Compress-Archive -Path (Join-Path $webSrc '*') -DestinationPath $webZip
  }

  Write-Host "Built outputs under: $outDir"
}
finally {
  Pop-Location
}
