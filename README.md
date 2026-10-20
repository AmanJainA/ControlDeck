# ControlDeck

ControlDeck is a responsive Flutter app launcher for bringing personal, professional, and creative tools into one organised dashboard.

## Features

- Premium dark and light themes with an olive accent
- Responsive dashboard for desktop, tablet, and mobile
- Search, category filters, and favourites
- Starter links for LifeHub, Notes, Railways, Interview, and Portfolio
- Add, edit, and remove app shortcuts
- Local persistence with `shared_preferences`
- Open web apps in the browser using `url_launcher`

## Run locally

Install Flutter stable, then from this repository run:

```bash
flutter pub get
flutter run
```

To run in Chrome:

```bash
flutter run -d chrome
```

## Project structure

- `lib/main.dart` — app UI and launcher logic
- `pubspec.yaml` — Flutter dependencies
- `analysis_options.yaml` — Dart lint configuration

## Starter destinations

The starter list includes LifeHub, Notes, Railways, Interview, and Portfolio. Some entries use repository links as placeholders. Use **Add app** or the menu on an app card to configure the actual deployed URL.

## Notes

ControlDeck is a launcher, not a shared sign-in system; each linked application keeps its own authentication. Shortcuts are saved locally on the device. Cloud sync and a secure admin account can be added in a later iteration.
