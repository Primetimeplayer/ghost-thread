# GhostThread

Offline-first app that resurfaces unfinished thoughts based on context.

GhostThread is for the ideas you start and never finish: a half-written plan, a
question you meant to answer, a note you abandoned. You capture a thought in a
few seconds, and the app brings it back when the moment is right — same place,
similar battery state, related note — instead of relying on a notification you
will swipe away.

Everything runs on-device. There is no account and no backend.

## Status

Scaffolding only. The app launches and shows a centered "GhostThread" title.
Models and services are placeholders; no features are implemented yet.

## Tech stack

- Flutter 3.50 (stable), Dart 3.14, Material 3
- [Riverpod](https://riverpod.dev) (`flutter_riverpod`) for state management
- [Hive](https://pub.dev/packages/hive) + `hive_flutter` for local storage
- `path_provider` for the app documents directory
- `flutter_local_notifications` for resurfacing reminders
- `geolocator`, `battery_plus`, `device_info_plus` and `intl` for context signals
- `uuid` for thread identifiers
- Targets Android, iOS and Web

## Project structure

```
lib/
  main.dart                  # App entry point, Riverpod scope, Material 3 theme
  models/
    ghost_thread.dart        # Core thread model
  services/
    storage_service.dart     # Hive-backed persistence (planned)
    embedding_service.dart   # On-device text embeddings (planned)
    context_service.dart     # Battery/location/time/device context (planned)
    matching_service.dart    # Thread ↔ context scoring (planned)
    notification_service.dart# Local notifications (planned)
  providers/                 # Riverpod providers (empty for now)
  screens/
    home_screen.dart         # Thread list (placeholder)
    capture_screen.dart      # New thought (placeholder)
    thread_detail_screen.dart# Single thread (placeholder)
    settings_screen.dart     # Settings (placeholder)
  widgets/                   # Shared widgets (empty for now)
```

## Getting started

Requires Flutter 3.24 or newer (developed against 3.50 stable).

```bash
flutter pub get
flutter run        # pick a connected device, or:
flutter run -d chrome
```

Build for the web:

```bash
flutter build web
```

## Roadmap

1. Capture and persist thoughts with Hive.
2. Generate on-device embeddings for each thread.
3. Read context signals (time, place, battery, device state).
4. Match open threads against the current context and resurface the best ones.
5. Deliver resurfacing through local notifications and an in-app inbox.
