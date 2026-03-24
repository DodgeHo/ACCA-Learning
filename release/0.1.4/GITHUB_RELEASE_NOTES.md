# SAA 练习 v0.1.4

本次版本聚焦移动端 AI 面板即时刷新，以及应用名称统一。

## Highlights

- 修复手机端 AI 提问弹层中“收起 / 展开”和快捷提问按钮点击后界面不能立刻更新的问题
- 让 AI 弹层内的加载状态和对话历史在当前弹层里即时刷新
- 将应用显示名称统一调整为 `SAA 练习`
- 发布 Android 与 Web 的 0.1.4 构建产物

## Artifacts

- Android APK: aws_saa_trainer-v0.1.4+4-release.apk
- Android AAB: aws_saa_trainer-v0.1.4+4-release.aab
- Web ZIP: aws_saa_trainer-v0.1.4+4-web.zip
- Windows ZIP: aws_saa_trainer-v0.1.4+4-windows-x64.zip

## Notes

- Web 缓存版本已提升到 `aws-saa-web-v4`，避免部署后继续命中旧缓存
- 当前 Android release 构建仍使用调试签名；若要正式上架 Google Play，请先切换为正式 keystore 签名
