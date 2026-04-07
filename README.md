# ACCA Learning

ACCA 多科目题库训练应用，基于 Flutter 构建，支持 Windows、Android、Web（并保留 iOS/macOS/Linux 工程）。

## 当前范围

- 目标科目：pm、tx、fr、aa、fm、sbl、sbr、afm、apm、aaa
- 数据形态：题库资产位于 assets/banks/<subject>/
- 运行时资产：通过脚本切换到 assets/data.db 和 assets/questions.json
- 约束：数据库 schema 不变，仅替换 questions 行

## 主要能力

- 题目训练：会 / 不会 / 收藏状态标记，进度追踪，筛选与随机模式
- AI 讲解：支持兼容 OpenAI 协议的提供者配置
- 主观题展示：已支持 Case / Essay 结构化展示
- 图表题展示：支持 assets/exhibits/index.json 映射并在题面折叠展示
- 多端发布：脚本支持按科目生成 Android、Windows、Web 产物

## 快速开始

1. 安装依赖
   flutter pub get
2. 切换题库（示例：PM）
   powershell -ExecutionPolicy Bypass -File scripts/select_question_bank.ps1 -Bank pm
3. 本地运行
   flutter run

## 题库构建

### 从 PDF 构建

单科：
  powershell -ExecutionPolicy Bypass -File scripts/prepare_acca_bank.ps1 -Subject pm

全科：
  powershell -ExecutionPolicy Bypass -File scripts/prepare_acca_bank.ps1 -Subject all

### 从 OCR-DOCX 构建

单科：
  powershell -ExecutionPolicy Bypass -File scripts/prepare_acca_bank_from_docx.ps1 -Subject pm -OcrRoot ocr_packets

全科：
  powershell -ExecutionPolicy Bypass -File scripts/prepare_acca_bank_from_docx.ps1 -Subject all -OcrRoot ocr_packets

## 按科目打包

三端打包（Android + Windows + Web）：
  powershell -ExecutionPolicy Bypass -File scripts/build_multiplatform_bank_variant.ps1 -Bank pm -VersionTag 0.3.0

仅 Web：
  powershell -ExecutionPolicy Bypass -File scripts/build_multiplatform_bank_variant.ps1 -Bank pm -VersionTag 0.3.0 -NoAndroid -NoWindows

## 发布产物

- PM：release/0.3.0-pm/
- TX：release/0.3.0-tx/
- 上传与校验说明：release/0.3.0/UPLOAD_NOTES.md

## 仓库结构

- lib/: Flutter 业务代码
- assets/: 当前运行题库 + 分科 bank + exhibits
- scripts/: 构建、切库、OCR、打包脚本
- release/: 历史与当前发布产物

## 发布流程

1. 更新 CHANGELOG.md 与 pubspec.yaml 版本
2. 完成构建与校验（建议记录 SHA256）
3. 提交并打 tag
4. 发布到 GitHub Releases

## 许可证

MIT License
