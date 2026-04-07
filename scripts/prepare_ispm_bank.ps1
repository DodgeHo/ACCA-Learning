param(
  [string]$PdfRoot = ""
)

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $root

try {
  $resolvedRoot = $PdfRoot
  if ([string]::IsNullOrWhiteSpace($resolvedRoot)) {
    $candidate = Get-ChildItem -Path $root -Recurse -Directory | Where-Object {
      $dir = $_.FullName
      $has01 = Test-Path (Join-Path $dir '01-*')
      $has02 = Test-Path (Join-Path $dir '02-*')
      $has03 = Test-Path (Join-Path $dir '03-*')
      $hasPdf = (Get-ChildItem -Path $dir -Recurse -File -Filter '*.pdf' -ErrorAction SilentlyContinue | Select-Object -First 1) -ne $null
      return $has01 -and $has02 -and $has03 -and $hasPdf
    } | Select-Object -First 1
    if ($null -eq $candidate) {
      throw "Cannot locate ISPM PDF root automatically. Pass -PdfRoot explicitly."
    }
    $resolvedRoot = $candidate.FullName
  }

  py scripts/build_ispm_bank_from_pdfs.py --pdf-root "$resolvedRoot" --template-db assets/data.db
  if ($LASTEXITCODE -ne 0) {
    throw "Build ISPM bank assets failed"
  }

  Write-Host "Prepared ISPM bank assets at assets/banks/ispm"
}
finally {
  Pop-Location
}
