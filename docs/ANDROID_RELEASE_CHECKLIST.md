# Android release checklist

Updated 14 November 2026. **Not Release Ready**. Checkboxes track executed evidence
or explicit owner confirmation. Version `1.0.0+2` was selected for release preparation,
with the existing application ID retained. Owner confirmation is pending.

- [ ] Application ID confirmed by owner, currently `com.homecircle.homecircle`
- [ ] App name confirmed by owner, currently `HomeCircle`
- [ ] Version name/code confirmed by owner, candidate `1.0.0` / `2`
- [ ] Branding approved for launcher, adaptive icon and splash
- [x] Android permissions reviewed, INTERNET and POST_NOTIFICATIONS
- [ ] Backend environment configured for production HTTPS
- [ ] Supabase configuration verified end to end
- [ ] Firebase configuration verified
- [ ] Database migrations applied and verified on the intended environment
- [ ] Live database, Storage and Realtime security tests passed
- [x] Isolated backend security tests passed
- [x] Flutter tests passed
- [x] Backend tests passed
- [ ] Guarded integration tests passed, currently skipped without test credentials
- [x] Unsigned Android release APK and AAB builds succeed
- [ ] Release signing configured securely
- [ ] Signed AAB produced
- [ ] Release-signed installation tested
- [x] Configured debug APK installed and launched to onboarding on the API 37 emulator
- [ ] Critical workflows A–F tested on device with real services
- [ ] Physical-device, TalkBack and populated-household performance acceptance
- [ ] Privacy policy prepared
- [ ] Required Google Play declarations prepared
- [ ] No unresolved release-blocking P0/P1 defects or acceptance gaps

## Secure signing

Use an existing approved keystore supplied by its owner. Copy
`mobile/android/key.properties.example` to ignored `mobile/android/key.properties`
and provide all four values locally. Relative keystore paths resolve from
`mobile/android`. Environment variables take precedence over the corresponding
property fields and are suitable for CI secret injection.

| Property | Environment variable |
| --- | --- |
| `storeFile` | `HOMECIRCLE_KEYSTORE_FILE` |
| `storePassword` | `HOMECIRCLE_STORE_PASSWORD` |
| `keyAlias` | `HOMECIRCLE_KEY_ALIAS` |
| `keyPassword` | `HOMECIRCLE_KEY_PASSWORD` |

An absent configuration produces unsigned release artifacts. Partial configuration
fails release task configuration without printing values. Release builds use the
release signing configuration only when all fields exist. Existing debug builds use
the Android development signing configuration. Verify the certificate fingerprint
against the owner's expected identity before distribution.

```powershell
# From mobile, after providing the intended public HTTPS release configuration.
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --no-pub --dart-define-from-file=config.release.local.json
flutter build appbundle --release --no-pub --dart-define-from-file=config.release.local.json
# Use the installed Android build-tools apksigner to verify the APK.
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

Keep `config.release.local.json` ignored and use only the API URL, Supabase URL and
public publishable/anon key. No server, worker or signing secret belongs in Dart
defines. AAB files require the approved signing identity for Play submission.
Signing and Flutter Android release procedures are described in the official
documentation. [Android signing](https://developer.android.com/studio/publish/app-signing),
[Flutter Android release](https://docs.flutter.dev/deployment/android)

Publication and production key creation require separate owner authorization.
See the artifact evidence and pending installation checks in the QA report.
[Final QA report](FINAL_QA_REPORT.md)
