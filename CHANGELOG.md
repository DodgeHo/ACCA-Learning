# Changelog

## 0.2.1 - 2026-03-28
- Android multi-app installability:
  - fixed SAP package id to `com.example.aws_sap_trainer`
  - fixed ISPM package id to `com.example.ispm.trainer`
  - ensured SAA / SAP / ISPM APKs can coexist on one Android device
- Release asset naming:
  - aligned release artifact filenames with per-bank app identity
  - published corrected Android artifacts for SAP and ISPM

## 0.2.0 - 2026-03-26
- Multi-bank delivery:
  - added developer bank switching workflow for SAA / SAP / ISPM without database schema changes
  - added Android bank variant build script for `0.2.0-saa`, `0.2.0-sap`, and `0.2.0-ispm`
  - added SAP PDF extraction and bank asset build pipeline
  - added ISPM PDF build pipeline with OCR fallback and manifest output
- Quiz UX:
  - preserved existing SAA objective quiz behavior while adding ISPM question type detection
  - answer panel can now show `正确答案` plus `要点点评（PDF）`
  - AI quick prompts now route by question type for objective / case / essay flows
- Web entry routing:
  - root entry page now exposes `/saa/`, `/sap/`, and `/ispm/`
- Release notes:
  - current ISPM OCR extraction quality is not sufficient for full production confidence; release draft keeps this as an explicit risk

## 0.1.6 - 2026-03-25
- Release packaging:
  - prepared Android release artifacts for v0.1.6 (`APK` + `AAB`)
  - prepared Web release artifact for v0.1.6 (`web.zip`)
  - prepared Windows release artifact for v0.1.6 (`windows-x64.zip`)
  - bumped web cache version to `aws-saa-web-v6`

## 0.1.5 - 2026-03-24
- Settings UX:
  - removed manual save button in settings and switched to auto-save behavior
- Compliance notice:
  - added first-launch learning notice dialog (shown once per device)
- Desktop stability:
  - improved Windows desktop data loading compatibility for local database files
- Release packaging:
  - prepared Android release artifacts for v0.1.5 (`APK` + `AAB`)
  - prepared Web release artifact for v0.1.5 (`web.zip`)
  - prepared Windows release artifact for v0.1.5 (`windows-x64.zip`)
  - bumped web cache version to `aws-saa-web-v5`

## 0.1.4 - 2026-03-24
- Mobile AI sheet polish:
  - fixed AI quick-prompt collapse and shortcut actions so the bottom sheet updates immediately
  - kept AI loading and chat-history changes in sync inside the mobile bottom sheet
- App naming:
  - renamed the displayed app title across Flutter, Android, iOS, Web, Windows, Linux, and macOS to `SAA 练习`
- Release packaging:
  - prepared Android release artifacts for v0.1.4 (`APK` + `AAB`)
  - prepared Web release artifact for v0.1.4 (`web.zip`)
  - bumped web cache version to `aws-saa-web-v4`

## 0.1.3 - 2026-03-15
- Mobile UX and state continuity:
  - improved AI quick-prompt collapse and expand responsiveness with animated feedback
  - added visible question transition animation for swipe and previous/next navigation
  - reduced compact-mode vertical chrome by shrinking the app bar and tightening question headline layout
  - added clear current-question status indicators for Know / DontKnow / Favorite
  - restored the last visited question when reopening the app on Android
- Release packaging:
  - prepared Android release artifacts for v0.1.3 (`APK` + `AAB`)
  - prepared Web release artifact for v0.1.3 (`web.zip`)

## 0.1.2 - 2026-03-13
- Release packaging:
  - prepared Android release artifacts for v0.1.2 (`APK` + `AAB`)
  - prepared Web release artifact for v0.1.2 (`web.zip`)
- Mobile interaction refinement:
  - reduced vertical chrome on quiz page by moving prev/next into headline controls
  - added swipe left/right navigation for question paging
  - improved AI sheet readability with collapsible quick prompts and larger default reading area

## 0.1.1 - 2026-03-12
- Android release packaging:
  - prepared release artifacts for Android upload workflow
  - aligned app semantic version to `0.1.1+1`
- Mobile UX improvements:
  - added compact header collapse/expand for quiz mode
  - moved AI interaction to touch-first bottom sheet flow
  - added fixed composer with send button in AI panel
  - improved mobile readability controls for question font size
- Stable random mode:
  - random order now uses a persisted deterministic seed
  - added seed management in settings for cross-device migration

## 1.2.0 - 2026-03-09
- Reliability & data safety:
  - fixed native DB repair flow to preserve `chat_history` in addition to `user_status`
  - added chat history export/import (JSON) in settings for manual backup and restore
- Documentation alignment:
  - synced README/INSTALL with current AI integration status
  - added local data backup recommendations and web deployment checklist updates
- Testing & release quality:
  - added `AiClient` unit tests (empty key, unsupported provider, non-2xx error readability, success parsing)
  - updated web service worker cache versioning guidance and bumped `CACHE_VERSION`
- Progress analytics:
  - added status ratio, recent wrong-question trend, and favorite hotspots summary in progress view
- Release doc cleanup:
  - removed internal sprint execution document
  - removed outdated Python MVP planning document to avoid confusion with Flutter implementation

## 1.1.0 - 2026-02-26
- Added QBank Trainer enhancements:
  - filtering by status (All/Know/DontKnow/Favorite)
  - random/ordered question mode
  - jump to specific question number
  - persistent progress tracking (last index saved per database)
  - progress display label
  - improved DeepSeek API error handling with dialog and logging
- Persisted filter/random settings across sessions

## 1.0.2 - 2026-02-11
- Added MIT LICENSE file
- Clarified upstream license status in README and ISSUES

## 1.0.1 - 2026-02-11
- Added course attribution and framework source notes
- Documented license status of upstream framework repo
- Refreshed README and ISSUES for GitHub publishing

## 1.0.0 - 2026-02-11
- Rebuilt project for AWS SAA learning materials
- Converted local _zh.srt subtitles into translations/ markdown files
- Regenerated course content, audit, and progress templates
- Updated README and skill instructions
