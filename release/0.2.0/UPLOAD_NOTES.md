# Release v0.2.0 Upload Notes

## Scope

- Stable banks:
  - `saa`
  - `sap`
- Experimental bank:
  - `ispm`

## Artifact Directories (Per-Variant)

Each bank variant has its own release directory with APK + AAB + Windows exe:

### release/0.2.0-saa/ (Stable)
- `aws_saa_trainer-v0.2.0+7-saa-release.apk`
- `aws_saa_trainer-v0.2.0+7-saa-release.aab`
- `aws_saa_trainer-v0.2.0+7-saa-windows-x64.zip`
- `aws_saa_trainer-v0.2.0+7-web-multibank.zip`  ← shared web deploy (all 3 routes)

### release/0.2.0-sap/ (Stable)
- `aws_saa_trainer-v0.2.0+7-sap-release.apk`
- `aws_saa_trainer-v0.2.0+7-sap-release.aab`
- `aws_saa_trainer-v0.2.0+7-sap-windows-x64.zip`

### release/0.2.0-ispm-experimental/ (Experimental)
- `aws_saa_trainer-v0.2.0+7-ispm-experimental-release.apk`
- `aws_saa_trainer-v0.2.0+7-ispm-experimental-release.aab`
- `aws_saa_trainer-v0.2.0+7-ispm-experimental-windows-x64.zip`

## SHA256 — SAA (Stable)

- `aws_saa_trainer-v0.2.0+7-saa-release.apk`
  - `37D749B0833655309F592E663193EF25D4357246E75F21797EB575D7B601EA81`
- `aws_saa_trainer-v0.2.0+7-saa-release.aab`
  - `CCFFDB76ED4D0982E51A2B2FCF9946C2093BCBBE2F348BB9C9115FF098DE7C7B`
- `aws_saa_trainer-v0.2.0+7-saa-windows-x64.zip`
  - `01C3C78C0DC7689A27BBB15128E7EAC89B83B2B65B2D0727AC6A0FE1885C1541`
- `aws_saa_trainer-v0.2.0+7-web-multibank.zip`
  - `1765742BE96408B009524CD516A411F420002ADD490B681747A5181E76FF470A`

## SHA256 — SAP (Stable)

- `aws_saa_trainer-v0.2.0+7-sap-release.apk`
  - `D57E621791EE0FF5E0F1E64C91B331EA25245E68CDEEEA2B34BAD67E55D93FD6`
- `aws_saa_trainer-v0.2.0+7-sap-release.aab`
  - `2CFF49A1A327C07BA4EB2151F70E46413EF6296570C7F9431F11C0C1A94831A7`
- `aws_saa_trainer-v0.2.0+7-sap-windows-x64.zip`
  - `FA8F7FEFC3D704A1284EFC203627880A54C3A7526290CFFB7686241C461FE3C2`

## SHA256 — ISPM (Experimental)

- `aws_saa_trainer-v0.2.0+7-ispm-experimental-release.apk`
  - `01FBA20B0CB8A8909E6978D7F8F2D35DF1028A76D7748E41C3FF86E425E93AD4`
- `aws_saa_trainer-v0.2.0+7-ispm-experimental-release.aab`
  - `AE27CE7D393CCC4949098A1A4A359B25849F0CDF8C78EEB60EA3D3BD28CF2C06`
- `aws_saa_trainer-v0.2.0+7-ispm-experimental-windows-x64.zip`
  - `035B0D62FD2F609340C99B6B7F253455E46A45917A4A0180B313303F422D9C84`

## Version

- pubspec version: `0.2.0+7`
- web cache version: `aws-saa-web-v7`
- db asset version: `2026-03-26-multibank-v3`

## Bank Pipeline Summary

- SAA:
  - source: existing app assets
- SAP:
  - source: `题库/2.中文SAP-C02 - 含答案.pdf`
  - generated questions: `527`
- ISPM:
  - source: `题库/信息系统项目管理师历年真题（熟悉考情）`
  - generated questions: `267`
  - by type:
    - objective: `219`
    - case: `24`
    - essay: `24`

## Build Commands

```powershell
flutter pub get
flutter analyze

.\scripts\select_question_bank.ps1 -Bank saa
.\scripts\build_android_bank_variant.ps1 -Bank saa -VersionTag 0.2.0

.\scripts\prepare_sap_bank.ps1
.\scripts\build_android_bank_variant.ps1 -Bank sap -VersionTag 0.2.0

.\scripts\prepare_ispm_bank.ps1
.\scripts\build_android_bank_variant.ps1 -Bank ispm -VersionTag 0.2.0
```

## Release Notes Draft

1. Added schema-preserving multi-bank workflow for SAA / SAP / ISPM.
2. Added SAP PDF ingestion and ISPM PDF plus OCR asset generation scripts.
3. Added ISPM-aware quiz display for objective, case, and essay presentation.
4. Added answer panel support for PDF key-point commentary.
5. Added AI quick-prompt routing by question type.
6. Added root entry links for `/saa/`, `/sap/`, and `/ispm/`.

## Important Risks

- `ispm` OCR output is currently noisy across a large share of scanned PDFs.
- This impacts question readability and answer reliability, especially for objective questions.
- Do not create a final public `v0.2.0` git tag until ISPM content is manually corrected or the release scope explicitly excludes that quality bar.

## Publish Recommendation

1. Release `0.2.0-saa` and `0.2.0-sap` as stable outputs.
2. Treat `0.2.0-ispm` as experimental unless manual proofreading is completed.
3. Generate SHA256 and final upload notes only after artifacts are built.

## Current Completion

- Completed:
  - Built all 3 per-variant release directories (saa / sap / ispm-experimental)
  - Each variant has: APK + AAB + Windows zip
  - Web multibank zip (shared) placed in 0.2.0-saa/
  - Generated SHA256 for all 10 artifacts
- Pending:
  - release tag and publication actions