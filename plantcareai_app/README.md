# PlantCareAI Flutter Application

This directory contains the source code for the PlantCareAI Flutter mobile application. This app provides the user interface for interacting with the plant identification and health assessment features, managing user data, and communicating with the backend server.

## Overview

The Flutter app allows users to:
* Sign up and log in using Firebase Authentication.
* Capture images using the device camera or select images from the gallery.
* Send images to the backend server for analysis.
* Display the prediction results received from the backend (species, health, care info).
* Interact with an AI chatbot (powered by Google AI) for further plant inquiries.
* Save identified plants to a personal collection stored in Firebase Firestore.
* View and manage their saved plants.
* Manage user profile settings.

## Key Technologies & Packages

* **Flutter & Dart:** Core framework and language.
* **Provider:** For state management.
* **Firebase:**
    * `firebase_core`: For initializing Firebase.
    * `firebase_auth`: For user authentication.
    * `cloud_firestore`: For storing user plant collections and profile data.
    * `firebase_storage`: (Likely used) For storing user-uploaded plant images associated with their collection.
* **`http`:** For making API calls to the backend server.
* **`image_picker`:** For selecting images from the gallery or camera.
* **`google_generative_ai`:** For interacting with the Google AI API for the chatbot feature.
* **`font_awesome_flutter`:** For icons.
* *(Check `pubspec.yaml` for a complete list)*

## Directory Structure (`lib/` Focus)

The core application logic resides within the `lib/` directory:
lib/
├── core/
│   ├── providers/  # State management (e.g., PlantProvider, ThemeProvider)
│   ├── services/   # API clients (Prediction, Gemini), Firebase services (Auth, Firestore)
│   └── theme/      # Application theme data
├── features/
│   ├── auth/       # Authentication pages (Login, Signup)
│   ├── chat/       # Chatbot interface
│   ├── home/       # Main home/dashboard page
│   ├── plants/     # Plant scanning, prediction result, profile, collection pages & widgets
│   ├── settings/   # User settings pages
│   └── welcome/    # Initial welcome/onboarding page
├── shared/           # Common widgets used across features (e.g., BaseScaffold, Popups)
└── main.dart         # Main application entry point, initializes Firebase, sets up providers & routes

## Setup

1.  **Flutter SDK:** Ensure you have the correct Flutter SDK installed and configured. Run `flutter doctor` to verify.
2.  **Navigate to App Directory:**
    ```bash
    cd path/to/CapStone/plantcareai_app
    ```
3.  **Firebase Setup:**
    * This app **requires** a Firebase project.
    * Follow the [FlutterFire installation guide](https://firebase.google.com/docs/flutter/setup) to connect your Firebase project to this Flutter app.
    * Download the configuration files from your Firebase project console:
        * `google-services.json` for Android (place in `android/app/`).
        * `GoogleService-Info.plist` for iOS (place in `ios/Runner/` via Xcode).
    * Enable **Authentication** (e.g., Email/Password), **Firestore**, and **Cloud Storage** in the Firebase Console.
4.  **Google AI API Key:**
    * The chatbot feature requires a Google AI API key.
    * Obtain a key from [Google AI Studio](https://aistudio.google.com/app/apikey).
    * You **must** provide this key securely to the app when running it. The recommended method is using `--dart-define` during the `flutter run` or `flutter build` command:
        ```bash
        flutter run --dart-define=GOOGLE_API_KEY=YOUR_ACTUAL_API_KEY
        ```
        *Consult `lib/core/services/gemini_api.dart` to see how the key is accessed (it likely uses `String.fromEnvironment`).*
    * **Do not hardcode the API key in the source code.**
5.  **Get Dependencies:**
    ```bash
    flutter pub get
    ```
6.  **Configure Backend URL:**
    * Open `lib/core/services/prediction_api.dart`.
    * Update the `uri` variable to point to the correct address of your running backend server (see main README for details on IP addresses for emulators/devices).

## Running the App

1.  **Ensure Backend is Running:** Start the Python backend server first (see `Server/README.md`).
2.  **Connect Device/Emulator:** Connect a physical device or start an Android emulator/iOS simulator.
3.  **Run App:** Navigate to `plantcareai_app/` in your terminal and run:
    ```bash
    # Replace YOUR_ACTUAL_API_KEY with your Google AI key
    flutter run --dart-define=GOOGLE_API_KEY=YOUR_ACTUAL_API_KEY
    ```

## Building for Release

Follow standard Flutter procedures for building release versions:

* **Android:** `flutter build apk` or `flutter build appbundle` (don't forget to pass `--dart-define` for the API key).
* **iOS:** `flutter build ios` (don't forget to pass `--dart-define`).

Refer to the [official Flutter documentation on building and releasing](https://docs.flutter.dev/deployment/build-android) for detailed instructions, including code signing.

## State Management

This application uses the **Provider** package for state management. Look in `lib/core/providers/` for the relevant provider classes and see how they are initialized in `main.dart`.

## Testing

Basic widget tests are located in the `test/` directory. Run tests using:

```bash
flutter test
```