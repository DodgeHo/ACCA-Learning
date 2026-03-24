# Release v0.1.5 Upload Notes

## Artifacts

- APK: release/0.1.5/aws_saa_trainer-v0.1.5+5-release.apk
- AAB: release/0.1.5/aws_saa_trainer-v0.1.5+5-release.aab
- Web ZIP: release/0.1.5/aws_saa_trainer-v0.1.5+5-web.zip
- Windows ZIP: release/0.1.5/aws_saa_trainer-v0.1.5+5-windows-x64.zip

## SHA256

- aws_saa_trainer-v0.1.5+5-release.apk
  - 8149F04F556182AC49AFED1CCDABF59684413E85DE6708B0BB5034FCBC47142B
- aws_saa_trainer-v0.1.5+5-release.aab
  - 65E274A1556F8613C0725A16C1C3654BAE22339A4E471108A36E85987BC17B47
- aws_saa_trainer-v0.1.5+5-web.zip
  - 256DA6843CC4400B0E3B1CC1ACC65DFAFB6F11142D8D91E111601FD44F8202DB
- aws_saa_trainer-v0.1.5+5-windows-x64.zip
  - F0CCA35E1B7B9115F8B79F29D9CD7B5D0142C7919C8AEB9702F1429570983F4D

## Version

- pubspec version: 0.1.5+5
- web cache version: aws-saa-web-v5
- display name: SAA 练习

## Upload Notes

1. Google Play: upload AAB file.
2. Internal QA / sideload: use APK file.
3. Web deployment: extract web.zip and upload all files to static hosting root.
4. Windows distribution: extract windows zip and run aws_saa_trainer.exe.

## Important

Current Android release build uses debug signing in android/app/build.gradle.kts.
For production store release, replace with your release keystore signing config before final submission.
