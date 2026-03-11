param(
    [switch]$Debug,
    [switch]$Aab,
    [switch]$NoProxyMode,
    [switch]$SkipPubGet
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
    Write-Host "[build_android] flutter build appbundle --release"
    flutter build appbundle --release
    Write-Host "[build_android] Output: build/app/outputs/bundle/release/app-release.aab"
    exit $LASTEXITCODE
}

if ($Debug) {
    Write-Host "[build_android] flutter build apk --debug"
    flutter build apk --debug
    Write-Host "[build_android] Output: build/app/outputs/flutter-apk/app-debug.apk"
} else {
    Write-Host "[build_android] flutter build apk --release"
    flutter build apk --release
    Write-Host "[build_android] Output: build/app/outputs/flutter-apk/app-release.apk"
}

exit $LASTEXITCODE
