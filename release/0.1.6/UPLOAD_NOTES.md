# Release v0.1.6 Upload Notes

## Artifacts

- APK: release/0.1.6/aws_saa_trainer-v0.1.6+6-release.apk
- AAB: release/0.1.6/aws_saa_trainer-v0.1.6+6-release.aab
- Web ZIP: release/0.1.6/aws_saa_trainer-v0.1.6+6-web.zip
- Windows ZIP: release/0.1.6/aws_saa_trainer-v0.1.6+6-windows-x64.zip

## SHA256

- aws_saa_trainer-v0.1.6+6-release.apk
  - 04BD5EA69B29EFED532BEA5330E76D717F6EDD72DE0EE5AABF6868E8C36BE2A8
- aws_saa_trainer-v0.1.6+6-release.aab
  - 1D834A9C498101B5035E2631D189C16B1DD1EA83F265D977C8705ED3DB2D9C6E
- aws_saa_trainer-v0.1.6+6-web.zip
  - 78BF023D717EA5DBEB5877F4204929BB720138A7E6CDE3D09A1C79B76F476DCD
- aws_saa_trainer-v0.1.6+6-windows-x64.zip
  - 922B472C066286F5137D81DA79867CB08F492D4A6967DEB9F38D82FFEA356860

## Version

- pubspec version: 0.1.6+6
- web cache version: aws-saa-web-v6

## Upload Notes

1. Google Play: upload AAB file.
2. Internal QA / sideload: use APK file.
3. Web deployment: extract web.zip and upload all files to static hosting root.
4. Windows distribution: extract windows zip and run aws_saa_trainer.exe.

## Important

Current Android release build uses debug signing in android/app/build.gradle.kts.
For production store release, replace with your release keystore signing config before final submission.