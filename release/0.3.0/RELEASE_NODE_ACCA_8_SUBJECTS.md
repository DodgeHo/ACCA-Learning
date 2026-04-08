# Release Node: ACCA 8 Subjects Extension

## Scope

- Subject banks updated: fr, aa, fm, sbl, sbr, afm, apm, aaa
- Runtime compatibility: PM/TX/SAA/SAP/ISPM flows preserved
- Platforms validated per subject: android, windows, web

## Completed Steps

1. Repository and source readiness scan for ACCA banks
2. Bank assets rebuilt for 8 subjects
3. Bank switch and question-count smoke checks
4. Web builds completed for 8 subjects
5. Android and Windows builds completed for 8 subjects
6. App startup smoke check completed (web-server)
7. Build matrix and upload notes aligned
8. Checksums generated for 8-subject artifacts

## Key Outputs

- release/0.3.0/BUILD_MATRIX.md
- release/0.3.0/UPLOAD_NOTES_ACCA_8_SUBJECTS.md
- release/0.3.0/checksums-acca-8-subjects.sha256
- assets/banks/<subject>/{data.db,questions.json,manifest.json} for 8 subjects

## Validation Summary

- Subject question counts (smoke):
  - fr=196, aa=270, fm=251, sbl=206, sbr=258, afm=111, apm=91, aaa=93
- Artifacts verified for each subject:
  - Android APK
  - Windows x64 ZIP
  - Web ZIP
- Startup smoke check:
  - Web server launch succeeded for sbr on port 18080
- Active runtime bank reset:
  - pm

## Release Notes

- This node extends v0.3.0 with validated 8-subject ACCA bank packages and cross-platform artifacts.
- Existing published PM/TX assets remain unchanged in naming and compatibility.
- Wasm dry-run warnings exist in web builds (flutter_secure_storage_web), but standard web artifacts build successfully.
