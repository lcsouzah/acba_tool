# acba_tool

ACBA Tool is a mobile app that helps users simulate and validate disciplined crypto accumulation using the Adaptive Cost Basis Accumulation protocol.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Android release signing

Release builds require a signing key that is not checked in to version
control.  Place your keystore file under `android/app/keystore/` and provide
the following properties either as environment variables or in a non‑versioned
Gradle properties file (for example, in `~/.gradle/gradle.properties`):

```
KEYSTORE_PATH=/absolute/path/to/keystore.jks
KEYSTORE_PASSWORD=your_store_password
KEY_ALIAS=your_key_alias
KEY_PASSWORD=your_key_password
```

These values are loaded by `android/app/build.gradle.kts` when creating the
release signing configuration.  Keep any property files with these secrets
out of version control.