param(
  [string]$PdfPath = "",
  [string]$TxtPath = "tmp/sap_source.txt"
)

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $root

try {
  $resolvedPdf = $PdfPath
  if ([string]::IsNullOrWhiteSpace($resolvedPdf)) {
    $candidate = Get-ChildItem -Path $root -Recurse -File | Where-Object { $_.Name -match 'SAP-C02.*\.pdf$' } | Select-Object -First 1
    if ($null -eq $candidate) {
      throw "Cannot locate SAP PDF automatically. Pass -PdfPath explicitly."
    }
    $resolvedPdf = $candidate.FullName
  }

  $stagedPdf = "tmp/sap_source.pdf"
  New-Item -ItemType Directory -Force -Path "tmp" | Out-Null
  Copy-Item -Path $resolvedPdf -Destination $stagedPdf -Force

  py scripts/extract_pdf_to_txt.py --pdf $stagedPdf --out $TxtPath
  if ($LASTEXITCODE -ne 0) {
    throw "PDF extract failed"
  }

  py scripts/build_bank_assets_from_txt.py --txt $TxtPath --bank sap --template-db assets/data.db --source-doc "SAP-C02 PDF"
  if ($LASTEXITCODE -ne 0) {
    throw "Build SAP bank assets failed"
  }

  Write-Host "Prepared SAP bank assets at assets/banks/sap"
}
finally {
  Pop-Location
}
