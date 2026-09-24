# StockFlow

**Version 1.0.0** — first release.

Offline-first inventory management for small warehouses, retail teams and field crews.

Native Android app built with Flutter. Data is stored on-device (SharedPreferences),
so it works without a connection.

## Features
- Stock counts by location with cycle-count progress
- Item catalog with low-stock alerts
- Purchase orders (receive, track quantities)
- Partners & team with role-based permissions
- Transfers between locations
- Reports: valuation, low stock, movements, top movers
- CSV/PDF export
- Pro plan gating (in-app, no external billing)

## Run it
```bash
cd mobile
flutter run
```

## Build a release APK (for sharing)
```bash
cd mobile
flutter build apk --release
```
APK output: `mobile/build/app/outputs/flutter-apk/app-release.apk`
(debug-signed, so it installs directly on any Android device.)

## Structure
- `mobile/lib/main.dart` — app entry and routing
- `mobile/lib/store.dart` — on-device data layer (SharedPreferences)
- `mobile/lib/screens/` — feature screens
- `mobile/lib/widgets.dart` — shared UI (step rows, chips, progress bar)
- `mobile/lib/export.dart` — CSV/PDF export helpers

## Tech
Flutter (Dart) · shared_preferences · share_plus · pdf/printing