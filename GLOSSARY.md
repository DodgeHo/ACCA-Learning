# Glossary — 术语表（精简）

本文件收录 ACCA 题库应用中的核心术语与简短释义，供协作与发布查阅。

- Bank: 分科题库标识（如 `pm`、`tx`、`sbl`），对应 `assets/banks/<subject>/`。
- Runtime Assets: 运行时题库文件，固定为 `assets/data.db` 与 `assets/questions.json`。
- Select Bank: 切库操作，通过 `scripts/select_question_bank.ps1` 将分科资产同步到运行时文件。
- Manifest: 每科构建元数据文件，路径 `assets/banks/<subject>/manifest.json`。
- OCR Packet: 待 OCR 的汇总资料包，路径 `ocr_packets/<subject>/`。
- OCR DOCX Build: 使用 OCR 结果 DOCX 重建题库的流程（`prepare_acca_bank_from_docx.ps1`）。
- Objective / Case / Essay: 题型分流标签，用于渲染与 AI 提问策略。
- Exhibit Mapping: 图表映射机制，通过 `assets/exhibits/index.json` 将 `source_doc` 关联到图片资源。
- Source Doc: 题目来源追踪字段，通常编码为 `ACCA:<subject>:<type>:<file>#<block>`。
- Multiplatform Variant Build: 按科目输出 Android/Windows/Web 发布包的构建流程。
- Smoke Check: 切库后最小可用验证（启动成功、题目可加载、无明显异常）。
- Release Notes: 发布交付说明（产物列表、SHA256、时间戳、风险说明）。

（更多术语会在需要时追加）
