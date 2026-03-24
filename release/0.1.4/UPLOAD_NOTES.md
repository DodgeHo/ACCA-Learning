# Release v0.1.4 Upload Notes

## Artifacts

- APK: release/0.1.4/aws_saa_trainer-v0.1.4+4-release.apk
- AAB: release/0.1.4/aws_saa_trainer-v0.1.4+4-release.aab
- Web ZIP: release/0.1.4/aws_saa_trainer-v0.1.4+4-web.zip
- Windows ZIP: release/0.1.4/aws_saa_trainer-v0.1.4+4-windows-x64.zip

## SHA256

- aws_saa_trainer-v0.1.4+4-release.apk
  - 470C7B8FCAE0C909986674D539F3A88FBF80362E9CA7E55B8B850BD681B55A2B
- aws_saa_trainer-v0.1.4+4-release.aab
  - B9D397CDF91CD273FA3932D0136B913F4DAD44901EC36505C0602362305FDEC8
- aws_saa_trainer-v0.1.4+4-web.zip
  - F9563692542450F46B280EC20EEC17552590633E1D022CFCF6388F55AA2D27DD
- aws_saa_trainer-v0.1.4+4-windows-x64.zip
  - 6920A45D94E0DF7318208EE9BD7E6857177993D476D341B20285FD65A087FB4E

## Version

- pubspec version: 0.1.4+4
- web cache version: aws-saa-web-v4
- display name: SAA 练习

## Upload Notes

1. Google Play: upload AAB file.
2. Internal QA / sideload: use APK file.
3. Web deployment: extract web.zip and upload all files to static hosting root.
4. Windows distribution: extract windows zip and run aws_saa_trainer.exe.

## Important

Current Android release build uses debug signing in android/app/build.gradle.kts.
For production store release, replace with your release keystore signing config before final submission.
