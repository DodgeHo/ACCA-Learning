# SAA 练习 v0.1.5

本次版本聚焦设置体验、首次须知，以及桌面端稳定性。

## Highlights

- 设置页移除“保存”按钮，改为自动保存
- 首次打开弹出“仅供交流学习”须知（仅显示一次）
- 修复并增强 Windows 桌面端本地数据库兼容性，减少“题库为空”问题
- 发布 Android / Web / Windows 的 0.1.5 构建产物

## Artifacts

- Android APK: aws_saa_trainer-v0.1.5+5-release.apk
- Android AAB: aws_saa_trainer-v0.1.5+5-release.aab
- Web ZIP: aws_saa_trainer-v0.1.5+5-web.zip
- Windows ZIP: aws_saa_trainer-v0.1.5+5-windows-x64.zip

## Notes

- Web 缓存版本已提升到 `aws-saa-web-v5`，避免部署后继续命中旧缓存
- 当前 Android release 构建仍使用调试签名；若要正式上架 Google Play，请先切换为正式 keystore 签名
