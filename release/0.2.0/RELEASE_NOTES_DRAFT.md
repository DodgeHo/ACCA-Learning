# v0.2.0 Draft

## Highlights

- Added developer-oriented multi-bank delivery for SAA, SAP, and ISPM.
- Kept runtime database schema unchanged by switching full asset bundles instead of migrating tables.
- Added SAP PDF extraction flow and ISPM PDF plus OCR build flow.
- Added ISPM-aware quiz presentation with question type labels, type-specific AI prompts, and PDF key-point commentary support.
- Added first-class root entry links for `/saa/`, `/sap/`, and `/ispm/`.

## Validation Snapshot

- `flutter analyze`: passed
- bank switch script: validated for `saa`, `sap`, `ispm`
- SAP manifest: `527` questions generated
- ISPM manifest: `267` questions generated

## Known Risk

- ISPM scanned PDFs still produce noisy OCR output.
- Current ISPM assets prove the build pipeline, but not full content quality.
- Recommended public scope:
  - stable: `saa`, `sap`
  - experimental: `ispm`

## Suggested Tag Policy

- If shipping only stable banks, tag after generating final artifacts and checksums.
- If shipping all three banks under one public tag, first resolve ISPM content quality or explicitly label ISPM as experimental in release copy.