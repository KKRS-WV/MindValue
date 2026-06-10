# MindVault Frontend

Flutter Material 3 client for MindVault V1.

## First-Time Platform Generation

This repository contains the Flutter app source scaffold. After installing Flutter, generate the platform runner files once:

```powershell
flutter create . --project-name mindvault --org com.mindvault --platforms android,ios,web
```

Keep the existing `lib/`, `test/`, `pubspec.yaml`, and `analysis_options.yaml` files when Flutter asks about overwrites.

## Run

```powershell
flutter pub get
flutter run -d chrome
```

## Test

```powershell
flutter analyze
flutter test
```
