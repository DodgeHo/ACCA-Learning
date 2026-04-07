# Common Mistakes — 常见易错点汇总（精简）

以下为 ACCA 题库构建与发布中常见错误及快速修正建议。

1. 直接手改 `data.db`：优先修脚本后重建，避免数据漂移和不可复现。
2. 忽略切库步骤：打包前必须执行 `scripts/select_question_bank.ps1 -Bank <subject>`。
3. 只更新 JSON 不更新 DB（或反之）：`assets/questions.json` 与 `assets/data.db` 需要同步。
4. OCR 输入不完整：`ocr_packets/<subject>/` 缺少必要 DOCX 会导致重建失败。
5. 把讲义噪声当题目：白皮书、目录、版权页应在解析阶段过滤。
6. 主观题按客观题规则解析：SBL/SBR/AFM/APM/AAA 要优先保证题干完整与评分点。
7. 图表题未配置映射：未维护 `assets/exhibits/index.json` 会造成题面缺图。
8. 构建后不校验产物：发布前应记录 SHA256 并核对产物大小/时间戳。
9. 忘记恢复默认题库：批量构建后建议切回 PM，避免后续调试混淆。
10. 提交前不更新版本文档：`pubspec.yaml`、`CHANGELOG.md`、`release/*/UPLOAD_NOTES.md` 应保持一致。

（可根据项目与课程内容扩充）
