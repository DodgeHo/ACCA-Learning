# Release v0.1.2 Upload Notes

## Artifacts

- APK: release/0.1.2/aws_saa_trainer-v0.1.2+2-release.apk
- AAB: release/0.1.2/aws_saa_trainer-v0.1.2+2-release.aab
- Web ZIP: release/0.1.2/aws_saa_trainer-v0.1.2+2-web.zip

## SHA256

- aws_saa_trainer-v0.1.2+2-release.apk
  - 120BDEF5FC34D649C5A7B7734217A5DBF8390ABD1A1D396058E21F54CFAD26C3
- aws_saa_trainer-v0.1.2+2-release.aab
  - DCF9530979F6F84E0E3ACD1CCB991E37BE9C03F5C642C3F595B54D9C06353229
- aws_saa_trainer-v0.1.2+2-web.zip
  - 09DA872A3B143C9711551E01724537DBC4F74BE2C37A6F69D47A7DC363845041

## Version

- pubspec version: 0.1.2+2

## Upload Notes

1. Google Play: upload AAB file.
2. Internal QA / sideload: use APK file.
3. Web deployment: extract web.zip and upload all files to static hosting root.

## Important

Current Android release build uses debug signing in android/app/build.gradle.kts.
For production store release, replace with your release keystore signing config before final submission.
