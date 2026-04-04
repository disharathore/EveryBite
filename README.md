# EveryBite

EveryBite is a Flutter mobile application project.

## Tech Stack

- Flutter (Dart)
- MongoDB (user storage via mongo_dart)
- Google ML Kit

## Prerequisites

- Flutter SDK (3.x)
- Dart SDK (bundled with Flutter)
- Android Studio or VS Code with Flutter extensions
- MongoDB database (Atlas/local) and connection string

## Setup

1. Clone the repository.
2. Install dependencies:

```bash
flutter pub get
```

3. Create a `.env` file in the project root with:
   - `GROQ_API_KEY=...`
   - `GROQ_MODEL=llama-3.3-70b-versatile` (optional)
   - `MONGO_URI=mongodb+srv://<username>:<password>@<cluster-url>/<db>?retryWrites=true&w=majority`
   - `MONGO_DATA_API_URL=https://data.mongodb-api.com/app/<app-id>/endpoint/data/v1` (required for Flutter web)
   - `MONGO_DATA_API_KEY=<atlas-data-api-key>` (required for Flutter web)
   - `MONGO_DATA_SOURCE=Cluster0` (Atlas cluster name, required for Flutter web)
   - `MONGO_USERS_COLLECTION=users` (optional)

## Run

```bash
flutter run
```

## Build

Android APK:

```bash
flutter build apk
```

## Project Structure

- `lib/` application source code
- `assets/` images and media
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` platform folders

## Notes

- This repository includes generated platform files from Flutter.
- Keep secrets and API keys out of git where possible.
