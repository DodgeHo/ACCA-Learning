param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('saa','sap','ispm','pm','tx','fr','aa','fm','sbl','sbr','afm','apm','aaa')]
  [string]$Bank
)

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$bankDir = Join-Path $root "assets/banks/$Bank"
$targetJson = Join-Path $root 'assets/questions.json'
$targetDb = Join-Path $root 'assets/data.db'
$sourceJson = Join-Path $bankDir 'questions.json'
$sourceDb = Join-Path $bankDir 'data.db'

if (!(Test-Path $sourceJson)) {
  throw "Missing bank questions json: $sourceJson"
}
if (!(Test-Path $sourceDb)) {
  throw "Missing bank data db: $sourceDb"
}

Copy-Item -Path $sourceJson -Destination $targetJson -Force
Copy-Item -Path $sourceDb -Destination $targetDb -Force

Write-Host "Selected bank '$Bank'"
Write-Host "Updated assets/questions.json and assets/data.db"
