param(
  [ValidateSet('pm','tx','fr','aa','fm','sbl','sbr','afm','apm','aaa','all')]
  [string]$Subject = 'all',
  [string]$OcrRoot = 'ocr_packets'
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
    Write-Host "Preparing OCR-DOCX bank: $s"
    $args = @('scripts/build_acca_bank_from_docx.py', '--subject', $s, '--ocr-root', $OcrRoot, '--template-db', 'assets/data.db')
    py -3 @args
    if ($LASTEXITCODE -ne 0) {
      throw "Build ACCA bank from OCR-DOCX failed for subject '$s'"
    }
  }

  Write-Host "Prepared ACCA OCR-DOCX banks: $($subjects -join ', ')"
}
finally {
  Pop-Location
}
