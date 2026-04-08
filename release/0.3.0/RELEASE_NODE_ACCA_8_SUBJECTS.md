# 发布节点说明：ACCA 8 科目扩展

## 本次范围

- 更新科目：fr、aa、fm、sbl、sbr、afm、apm、aaa
- 兼容说明：保持 PM/TX/SAA/SAP/ISPM 现有流程兼容
- 平台范围：每个科目均完成 android、windows、web

## 已完成步骤

1. 仓库与题库源文件可用性扫描
2. 8 科 bank 资产重建
3. 切库与题量冒烟检查
4. 8 科 Web 构建
5. 8 科 Android 与 Windows 构建
6. 应用启动冒烟（web-server）
7. 构建矩阵与上传说明对齐
8. 8 科产物 SHA256 清单生成

## 关键产出

- release/0.3.0/BUILD_MATRIX.md
- release/0.3.0/UPLOAD_NOTES_ACCA_8_SUBJECTS.md
- release/0.3.0/checksums-acca-8-subjects.sha256
- 8 科 bank 资产：assets/banks/<subject>/{data.db,questions.json,manifest.json}

## 校验摘要

- 题量冒烟：
  - fr=196, aa=270, fm=251, sbl=206, sbr=258, afm=111, apm=91, aaa=93
- 每科产物核验通过：
  - Android APK
  - Windows x64 ZIP
  - Web ZIP
- 启动冒烟：
  - sbr 在 18080 端口成功启动 web-server
- 运行时默认 bank 已恢复：
  - pm

## 备注

- 本节点基于 v0.3.0 增加并验证了 8 科 ACCA 题库三端产物。
- 已发布 PM/TX 的产物命名与兼容性保持不变。
- Web 构建存在 wasm dry-run 告警（flutter_secure_storage_web），但不影响标准 Web 产物生成。
