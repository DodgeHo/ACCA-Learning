# ACCA 多科目题库与发包说明

## 1) 已支持科目（bank key）

- `pm` `tx` `fr` `aa` `fm` `sbl` `sbr` `afm` `apm` `aaa`

## 2) 建库（从 PDF 生成 assets/banks/<subject>/）

先安装依赖：

```powershell
py -m pip install pypdf
```

单科建库：

```powershell
.\scripts\prepare_acca_bank.ps1 -Subject pm
```

全科建库（不启用 OCR）：

```powershell
.\scripts\prepare_acca_bank.ps1 -Subject all
```

## 2.1) 建库（从 OCR 的 DOCX 结果生成 assets/banks/<subject>/）

当你已经在外部平台完成 OCR 并拿到 DOCX，可直接建库：

单科：

```powershell
.\scripts\prepare_acca_bank_from_docx.ps1 -Subject pm -OcrRoot ocr_packets
```

全科：

```powershell
.\scripts\prepare_acca_bank_from_docx.ps1 -Subject all -OcrRoot ocr_packets
```

说明：
- 会生成并覆盖 `assets/banks/<subject>/data.db`、`questions.json`、`manifest.json`。
- 保持数据库 schema 不变，仅替换 `questions` 行。
- OCR-DOCX 适合先快速建可用库，再做人工抽样修订。

## 3) 切换当前题库（用于运行/打包）

```powershell
.\scripts\select_question_bank.ps1 -Bank fr
```

该命令会覆盖：
- `assets/data.db`
- `assets/questions.json`

## 4) 每科单独发包（Android + Windows + Web）

```powershell
.\scripts\build_multiplatform_bank_variant.ps1 -Bank fr -VersionTag 0.3.0
```

输出目录示例：
- `release/0.3.0-fr/acca-fr-0.3.0-android.apk`
- `release/0.3.0-fr/acca-fr-0.3.0-windows-x64.zip`
- `release/0.3.0-fr/acca-fr-0.3.0-web.zip`

## 5) OCR 何时需要

当 PDF 抽取文本极少（例如提取后仅几个字符）或乱码严重时，需要 OCR。

建议流程：
1. 先不启用 OCR 跑一次建库。
2. 查看每个 bank 的 `assets/banks/<subject>/manifest.json`：若题量明显偏低，再启用 OCR 重建。
3. 对 OCR 结果做抽样质检（题干、选项、答案标记、要点点评）。

## 6) OCR 安装与命令

### 安装（Windows）

```powershell
winget install --id oschwartz10612.Poppler -e
winget install --id UB-Mannheim.TesseractOCR -e
```

安装后建议重开终端，再检查：

```powershell
Get-Command pdftotext
Get-Command pdftoppm
Get-Command tesseract
```

### 启用 OCR 建库

单科：

```powershell
.\scripts\prepare_acca_bank.ps1 -Subject sbl -EnableOcr
```

全科：

```powershell
.\scripts\prepare_acca_bank.ps1 -Subject all -EnableOcr
```

> 注意：OCR 会显著增加耗时；建议只对题量异常低或扫描件占比高的科目启用。

## 7) ACCA 主观题质量建议（重要）

- SBL/SBR/AFM/APM/AAA 以主观题为主，建议优先关注题干结构和评分点完整性，而不是选项提取。
- 首轮导入建议按以下顺序抽检：
	1. 题干是否完整（Requirement/Question 段落是否截断）
	2. 要点点评是否进入 `explanation_zh`
	3. source_doc 是否可追溯到原 OCR 文档块
- 若发现误切分严重，优先修正规则后重建，不要手改数据库。
