# EcoTrace - Mobile App

Flutter client for EcoTrace (see the [root README](../README.md) for the full system).

```bash
flutter pub get
flutter run        # API defaults to http://10.0.2.2:8000/api on Android emulators
```

Override the API base URL with `--dart-define=API_URL=...`. The logo used on the welcome, login and home screens is `assets/images/bg.png` (declared in `pubspec.yaml`).

Notifications expand to show details and linked requests. They can be marked read, deleted individually, or cleared all at once.
