<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="./assets/provii-logo-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="./assets/provii-logo-light.png">
    <img alt="Provii" src="./assets/provii-logo-light.png" width="200">
  </picture>
</p>

<h1 align="center">Provii</h1>

<p align="center">Prove your age without proving your identity.</p>

<p align="center">
  <a href="https://github.com/provii/provii-mobile/actions/workflows/ci.yml"><img src="https://github.com/provii/provii-mobile/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/licence-AGPL--3.0--only-blue" alt="Licence: AGPL-3.0-only">
  <img src="https://img.shields.io/badge/iOS-17.6%2B-000000?logo=apple&logoColor=white" alt="iOS 17.6+">
  <img src="https://img.shields.io/badge/Android-10%2B-3DDC84?logo=android&logoColor=white" alt="Android 10+">
</p>

## How it works

You visit an approved issuer once. They check your identity document and confirm your date of birth. The app receives a cryptographic credential signed by that issuer and stores it in platform secure storage on your device, protected by biometric authentication. Nobody else holds a copy.

When a website needs to confirm you are old enough, the app generates a zero knowledge proof from that credential. The proof reveals one fact: you meet the age threshold. Nothing else leaves your phone. Not your name, not your birthdate, not the document you used for verification, not even the issuer who verified you. The relying party learns "old enough" and moves on. No record links your activity between different sites.

Private by design. Over fifty languages are supported on each platform, with full right-to-left layout support, so the experience remains consistent whether someone reads left to right, right to left, or uses a script with complex shaping rules that many apps neglect entirely. Every string is fully localised.

## For developers

The app is native on both platforms, sharing a Rust cryptography engine through UniFFI generated bindings. iOS receives Swift bindings via a pre-built XCFramework and C FFI. Android receives Kotlin bindings via JNA. All credential storage, key management, proof generation, and signature verification happens in that shared Rust layer.

| Layer | Technology |
| --- | --- |
| iOS UI | SwiftUI, Swift Concurrency |
| Android UI | Jetpack Compose, Material 3 (BOM 2026.01.01), Kotlin 2.3.10 |
| Crypto engine | Rust via UniFFI (XCFramework on iOS, JNA on Android) |
| Local storage | iOS Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), Android Keystore + EncryptedSharedPreferences |
| Minimum iOS | 17.6 |
| Minimum Android | API 29 (Android 10) |

## Building from source

Both platforms need the pre-built ProviiSDK bindings. These are not committed to the repository. Contact the maintainers for access or build them from the `provii-mobile-sdk` repository.

### iOS

Requires Xcode with iOS 17.6+ SDK and Ruby (for CocoaPods and Fastlane). Place the ProviiSDK XCFramework at `ios/Frameworks/ProviiSDK.xcframework`.

```bash
cd ios
bundle install
pod install --repo-update
open wallet.xcworkspace
```

Build and run from Xcode using the `wallet` scheme. Use the workspace file, not the `.xcodeproj`, so CocoaPods dependencies resolve correctly.

### Android

Requires JDK 17 and Android SDK with API 36 (compile SDK). Place the native `.so` libraries at `android/app/src/main/jniLibs/`.

```bash
cd android
./gradlew assembleDebug
```

Or open the `android/` directory in Android Studio and run the `app` configuration. Gradle 9.3.1 is bundled via the wrapper.

## Contributing

This project requires a signed Contributor Licence Agreement before we can merge pull requests. See [CLA.md](CLA.md) for the full text and signing instructions.

## Licence

[GNU Affero General Public License, version 3 only](./LICENSE). Copyright 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust.

Third party dependency licences are listed in [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
