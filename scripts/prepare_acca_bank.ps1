param(
  [ValidateSet('pm','tx','fr','aa','fm','sbl','sbr','afm','apm','aaa','all')]
  [string]$Subject = 'all',
  [string]$PdfRoot = '.',
  [switch]$EnableOcr
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
    Write-Host "Preparing bank: $s"
    $args = @('scripts/build_acca_bank_from_pdfs.py', '--subject', $s, '--pdf-root', $PdfRoot, '--template-db', 'assets/data.db')
    if ($EnableOcr) {
      $args += '--enable-ocr'
    }

    py @args
    if ($LASTEXITCODE -ne 0) {
      throw "Build ACCA bank failed for subject '$s'"
    }
  }

  Write-Host "Prepared ACCA banks: $($subjects -join ', ')"
}
finally {
  Pop-Location
}
