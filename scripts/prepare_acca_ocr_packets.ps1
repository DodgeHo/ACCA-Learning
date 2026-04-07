param(
  [ValidateSet('pm','tx','fr','aa','fm','sbl','sbr','afm','apm','aaa','all')]
  [string]$Subject = 'all',
  [string]$PdfRoot = '.',
  [int]$MinTextThreshold = 240,
  [int]$MaxPagesPerPdf = 220
)

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $root

try {
  $subjects = if ($Subject -eq 'all') {
    @('pm','tx','fr','aa','fm','sbl','sbr','afm','apm','aaa')
  } else {
    @($Subject)
  }

  foreach ($s in $subjects) {
    Write-Host "Preparing OCR packet: $s"
    py scripts/build_acca_ocr_packets.py --subject $s --pdf-root $PdfRoot --min-text-threshold $MinTextThreshold --max-pages-per-pdf $MaxPagesPerPdf
    if ($LASTEXITCODE -ne 0) {
      throw "Build OCR packet failed for subject '$s'"
    }
  }

  Write-Host "Prepared OCR packets: $($subjects -join ', ')"
}
finally {
  Pop-Location
}
