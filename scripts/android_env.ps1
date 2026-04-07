param(
    [string]$JavaHome = "C:\Program Files\Android\Android Studio\jbr",
    [string]$HttpProxy = "http://127.0.0.1:7892",
    [string]$HttpsProxy = "http://127.0.0.1:7892",
    [string]$AllProxy = "socks5://127.0.0.1:7891",
    [string]$NoProxy = "localhost,127.0.0.1,192.168.*",
    [switch]$NoProxyMode
)

$ErrorActionPreference = "Stop"

$env:JAVA_HOME = $JavaHome
$env:Path = "$($env:JAVA_HOME)\bin;$($env:Path)"

if ($NoProxyMode) {
    Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:ALL_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:NO_PROXY -ErrorAction SilentlyContinue
    Write-Host "[android_env] Proxy disabled for this session."
} else {
    $env:HTTP_PROXY = $HttpProxy
    $env:HTTPS_PROXY = $HttpsProxy
    $env:ALL_PROXY = $AllProxy
    $env:NO_PROXY = $NoProxy
    Write-Host "[android_env] Proxy enabled: HTTP/HTTPS=$HttpProxy, SOCKS=$AllProxy"
}

Write-Host "[android_env] JAVA_HOME=$($env:JAVA_HOME)"
