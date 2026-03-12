# Release v0.1.1 Upload Notes

## Artifacts

- APK: release/0.1.1/aws_saa_trainer-v0.1.1+1-release.apk
- AAB: release/0.1.1/aws_saa_trainer-v0.1.1+1-release.aab
- Web ZIP: release/0.1.1/aws_saa_trainer-v0.1.1+1-web.zip

## SHA256

- aws_saa_trainer-v0.1.1+1-release.apk
  - 9AA7BAFB9D391687B4849E366DA45D2EB06D078E73E1FF5F8016B6E90A0F60B5
- aws_saa_trainer-v0.1.1+1-release.aab
  - 1DD518665AEA1844E4BDFF0DE87D932D4DE1454646700C6EB96FC065D9D07AB1

## Version

- pubspec version: 0.1.1+1
- Android versionName/versionCode are sourced from Flutter version in pubspec

## Important Before Store Upload

Current Android release build is configured with debug signing:

- android/app/build.gradle.kts -> buildTypes.release.signingConfig = signingConfigs.getByName("debug")

For production store upload, replace this with your release keystore signing config before final upload.

## Suggested Upload Flow

1. Use AAB for Google Play upload.
2. Keep APK for local QA/sideload distribution.
3. Use Web ZIP for static hosting deployment (Nginx/S3/Cloudflare Pages/etc.).
4. Verify SHA256 after transfer.
5. Tag source as v0.1.1 in source control after final verification.
