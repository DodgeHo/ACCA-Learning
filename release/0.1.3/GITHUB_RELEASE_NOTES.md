# AWS SAA Trainer v0.1.3

本次版本聚焦移动端交互体验和状态连续性。

## Highlights

- 优化 AI 快捷提问区的收起 / 展开响应，加入更直接的动画反馈
- 为左右滑题、上一题、下一题加入可见的切题过渡动画
- 收紧紧凑模式顶部空间占用，减少手机界面竖向浪费
- 为当前题目增加清晰的“会 / 不会 / 收藏”已选状态提示
- Android 重新打开应用后恢复到上次做到的题目位置

## Artifacts

- Android APK: aws_saa_trainer-v0.1.3+3-release.apk
- Android AAB: aws_saa_trainer-v0.1.3+3-release.aab
- Web ZIP: aws_saa_trainer-v0.1.3+3-web.zip

## Notes

- Web 缓存版本已提升到 `aws-saa-web-v3`，避免部署后继续命中旧缓存
- 当前 Android release 构建仍使用调试签名；若要正式上架 Google Play，请先切换为正式 keystore 签名