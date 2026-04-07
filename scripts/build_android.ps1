param(
    [switch]$Debug,
    [switch]$Aab,
    [switch]$NoProxyMode,
    [switch]$SkipPubGet,
    [ValidateSet('saa','sap','ispm','pm','tx','fr','aa','fm','sbl','sbr','afm','apm','aaa')]
    [string]$Bank = 'saa'
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")

. (Join-Path $scriptDir "android_env.ps1") -NoProxyMode:$NoProxyMode

Set-Location $repoRoot

if (-not $SkipPubGet) {
    Write-Host "[build_android] flutter pub get"
    flutter pub get
}

if ($Aab) {
    if ($Debug) {
        throw "AAB does not support debug mode. Use release for appbundle."
    }
    Write-Host "[build_android] flutter build appbundle --release --flavor $Bank"
    flutter build appbundle --release --flavor $Bank
    Write-Host "[build_android] Output: build/app/outputs/bundle/${Bank}Release/app-${Bank}-release.aab"
    exit $LASTEXITCODE
}

if ($Debug) {
    Write-Host "[build_android] flutter build apk --debug --flavor $Bank"
    flutter build apk --debug --flavor $Bank
    Write-Host "[build_android] Output: build/app/outputs/flutter-apk/app-${Bank}-debug.apk"
} else {
    Write-Host "[build_android] flutter build apk --release --flavor $Bank"
    flutter build apk --release --flavor $Bank
    Write-Host "[build_android] Output: build/app/outputs/flutter-apk/app-${Bank}-release.apk"
}

exit $LASTEXITCODE
