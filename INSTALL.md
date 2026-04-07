# 安装与运行说明

本文档适用于 ACCA 多科目题库应用（Flutter）。

## 1. 环境准备

1. 安装 Flutter SDK（建议使用 stable 通道）。
2. 执行 `flutter doctor`，确保目标平台工具链可用。
3. 克隆仓库并安装依赖：

```bash
git clone https://github.com/DodgeHo/ACCA-Learning.git
cd ACCA-Learning
flutter pub get
```

## 2. 本地运行

先切换要练习的题库（示例 PM）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/select_question_bank.ps1 -Bank pm
```

再运行应用：

```bash
flutter run
```

可指定平台：

```bash
flutter run -d windows
flutter run -d chrome
flutter run -d android
```

## 3. 题库构建

从 PDF 构建（单科）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/prepare_acca_bank.ps1 -Subject pm
```

从 OCR DOCX 构建（单科）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/prepare_acca_bank_from_docx.ps1 -Subject pm -OcrRoot ocr_packets
```

## 4. 发布构建

按科目打三端包（Android + Windows + Web）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_multiplatform_bank_variant.ps1 -Bank pm -VersionTag 0.3.0
```

产物目录示例：

- `release/0.3.0-pm/`
- `release/0.3.0-tx/`

## 5. 数据与配置

- 运行时题库：`assets/data.db`、`assets/questions.json`
- 分科题库：`assets/banks/<subject>/`
- 图表映射：`assets/exhibits/index.json`
- AI Key 与本地设置：保存在设备本地存储

## 6. 相关文档

- 发布与校验：`release/0.3.0/UPLOAD_NOTES.md`
- 脚本总览：`scripts/README-acca.md`


