# ACCA Build Matrix (v0.3.0)

## Status Snapshot

- PM/TX: 已完成 Android + Windows + Web 构建与发布
- FR/AA/FM/SBL/SBR/AFM/APM/AAA: 已完成 bank 资产重建 + 切库冒烟 + Android/Windows/Web 三端构建

## Multiplatform Build Commands

通用脚本：

powershell -ExecutionPolicy Bypass -File scripts/build_multiplatform_bank_variant.ps1 -Bank <subject> -VersionTag 0.3.0

### FR

- Android + Windows + Web
  - powershell -ExecutionPolicy Bypass -File scripts/build_multiplatform_bank_variant.ps1 -Bank fr -VersionTag 0.3.0

### AA

- Android + Windows + Web
  - powershell -ExecutionPolicy Bypass -File scripts/build_multiplatform_bank_variant.ps1 -Bank aa -VersionTag 0.3.0

### FM

- Android + Windows + Web
  - powershell -ExecutionPolicy Bypass -File scripts/build_multiplatform_bank_variant.ps1 -Bank fm -VersionTag 0.3.0

### SBL

- Android + Windows + Web
  - powershell -ExecutionPolicy Bypass -File scripts/build_multiplatform_bank_variant.ps1 -Bank sbl -VersionTag 0.3.0

### SBR

- Android + Windows + Web
  - powershell -ExecutionPolicy Bypass -File scripts/build_multiplatform_bank_variant.ps1 -Bank sbr -VersionTag 0.3.0

### AFM

- Android + Windows + Web
  - powershell -ExecutionPolicy Bypass -File scripts/build_multiplatform_bank_variant.ps1 -Bank afm -VersionTag 0.3.0

### APM

- Android + Windows + Web
  - powershell -ExecutionPolicy Bypass -File scripts/build_multiplatform_bank_variant.ps1 -Bank apm -VersionTag 0.3.0

### AAA

- Android + Windows + Web
  - powershell -ExecutionPolicy Bypass -File scripts/build_multiplatform_bank_variant.ps1 -Bank aaa -VersionTag 0.3.0

## Optional Split Commands

仅 Web（先快测）：

- powershell -ExecutionPolicy Bypass -File scripts/build_multiplatform_bank_variant.ps1 -Bank <subject> -VersionTag 0.3.0 -NoAndroid -NoWindows

仅 Android + Windows（补齐）：

- powershell -ExecutionPolicy Bypass -File scripts/build_multiplatform_bank_variant.ps1 -Bank <subject> -VersionTag 0.3.0 -NoWeb

## Smoke-check Notes

- 切库冒烟题量：
  - fr=196, aa=270, fm=251, sbl=206, sbr=258, afm=111, apm=91, aaa=93
- Web 启动冒烟已通过（fr、sbr），其中 sbr 于 2026-04-08 在 web-server:18080 成功拉起。
- 8 科三端产物文件已核验存在（Android APK + Windows ZIP + Web ZIP）。
