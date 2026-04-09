# PeakMoto

Free & Open Source motorcycle navigation app. Forever free, no tracking, no account, no subscription.

A [Phanes Labs](https://github.com/phanes-io) project.

## Features (Planned)

- Curvy road routing with adjustable intensity
- Turn-by-turn navigation with voice guidance
- Offline maps & routing
- GPX import/export
- Dark theme optimized for outdoor use
- Glove-friendly touch targets

## Tech Stack

- **Flutter** – Cross-platform (iOS + Android)
- **flutter_map** – OpenStreetMap-based map rendering
- **BRouter** – Motorcycle-optimized routing engine
- **Riverpod** – State management

## Client-First Architecture

To stay free forever, compute-heavy tasks run on your device:
- Routing (BRouter local)
- Map tile rendering (vector tiles)
- GPX processing
- Curve analysis

## Development

```bash
flutter pub get
flutter run
```

## License

AGPL-3.0 – See [LICENSE](LICENSE)
