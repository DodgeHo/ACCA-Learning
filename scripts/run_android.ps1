param(
    [string]$DeviceId = "auto",
    [switch]$NoResident,
    [switch]$NoProxyMode,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")

. (Join-Path $scriptDir "android_env.ps1") -NoProxyMode:$NoProxyMode

Set-Location $repoRoot

function Get-AndroidDeviceIds {
    $text = adb devices | Out-String -Width 4096
    if ([string]::IsNullOrWhiteSpace($text)) {
        return @()
    }

    $androidIds = @()
    $lines = $text -split "`r?`n"
    foreach ($line in $lines) {
        if ($line -match "^\s*([\w\-\.:]+)\s+device\s*$") {
            $deviceId = $matches[1].Trim()
            $androidIds += $deviceId
        }
    }
    return $androidIds
}

function Get-EmulatorIds {
    $text = flutter emulators | Out-String -Width 4096
    if ([string]::IsNullOrWhiteSpace($text)) {
        return @()
    }

    $ids = @()
    $lines = $text -split "`r?`n"
    foreach ($line in $lines) {
        if ($line -match "^\s*Id\s+") {
            continue
        }
        if ($line -match "^\s*([A-Za-z0-9_.-]+)\s+.+\bandroid\b\s*$") {
            $id = $matches[1].Trim()
            $ids += $id
        }
    }
    return $ids
}

$selectedDeviceId = $DeviceId
if ($DeviceId -eq "auto") {
    $selectedDeviceId = $null
    $androidIds = @(Get-AndroidDeviceIds)
    if ($androidIds.Count -gt 0) {
        $selectedDeviceId = $androidIds[0]
    } else {
        $emulatorIds = @(Get-EmulatorIds)
        if ($emulatorIds.Count -gt 0) {
            $emulatorId = $emulatorIds[0]
            Write-Host "[run_android] No Android device online. Launching emulator: $emulatorId"
            flutter emulators --launch $emulatorId | Out-Host

            $maxAttempts = 30
            $sleepSeconds = 3
            $selectedDeviceId = $null
            for ($i = 0; $i -lt $maxAttempts; $i++) {
                Start-Sleep -Seconds $sleepSeconds
                $androidIds = @(Get-AndroidDeviceIds)
                if ($androidIds.Count -gt 0) {
                    $selectedDeviceId = $androidIds[0]
                    break
                }
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($selectedDeviceId)) {
        throw "No Android device available. Start an emulator first (flutter emulators --launch <id>) or pass -DeviceId explicitly."
    }
}

$args = @("run", "-d", $selectedDeviceId)
if ($NoResident) {
    $args += "--no-resident"
}

Write-Host "[run_android] flutter $($args -join ' ')"
if (-not $DryRun) {
    flutter @args
}
