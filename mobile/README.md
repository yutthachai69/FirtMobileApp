# relaycontent

## Push notifications

Push registration is optional and never blocks login. For Android/iOS, add the
Firebase native config files (`google-services.json` / `GoogleService-Info.plist`)
or provide these build-time defines:

`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, and
`FIREBASE_PROJECT_ID` (with optional `FIREBASE_STORAGE_BUCKET` and
`FIREBASE_IOS_BUNDLE_ID`). The app requests permission, registers the FCM token
at `/v1/devices`, and refreshes it when Firebase rotates the token.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
