# Release v0.1.3 Upload Notes

## Artifacts

- APK: release/0.1.3/aws_saa_trainer-v0.1.3+3-release.apk
- AAB: release/0.1.3/aws_saa_trainer-v0.1.3+3-release.aab
- Web ZIP: release/0.1.3/aws_saa_trainer-v0.1.3+3-web.zip

## SHA256

- aws_saa_trainer-v0.1.3+3-release.apk
  - 1A652D266D5AABFFFA5BB5540FB556A93F689010B7A10EAB28D67DC6295F94BE
- aws_saa_trainer-v0.1.3+3-release.aab
  - 419678CA8CAA384AB8D4B586F9C964EF3DD4CB9A85B89D690C42D31E1AFFE72D
- aws_saa_trainer-v0.1.3+3-web.zip
  - 4CCD9BC2A6E8E710ECF0702B83D74C01062FF91A14E68EAD35B60202AF7C6DDB

## Version

- pubspec version: 0.1.3+3
- web cache version: aws-saa-web-v3

## Upload Notes

1. Google Play: upload AAB file.
2. Internal QA / sideload: use APK file.
3. Web deployment: extract web.zip and upload all files to static hosting root.

## Important

Current Android release build uses debug signing in android/app/build.gradle.kts.
For production store release, replace with your release keystore signing config before final submission.