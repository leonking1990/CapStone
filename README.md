# PlantCareAI: Plant Species & Health Identification

This project combines a Flutter mobile application with a Python backend powered by Machine Learning to identify plant species, diagnose potential health issues, and provide relevant care information.

## Overview

Users can take or upload a picture of a plant using the Flutter app. The image is sent to a FastAPI backend server, which uses TensorFlow/Keras models to classify the plant's species and determine its health status (healthy or identifying a specific disease). The backend then queries the Perenual API (using the classified plant name) to enrich the prediction with detailed plant care information (watering, sunlight, description, etc.). The combined results are sent back to the Flutter app for display, and users can save identified plants to their collection managed via Cloud Firestore.

## Features

* **Image Upload/Capture:** Select photos from the gallery or capture new ones via the Flutter app.
* **Plant Species Identification:** Utilizes a custom-trained CNN model running on the backend.
* **Plant Health Assessment:** Identifies common plant diseases using a second CNN model on the backend.
* **Detailed Care Information:** Fetches watering, sunlight, cycle, and description data from the Perenual API based on the identified plant name.
* **Result Display:** Shows the identified species, health status, disease (if any), care info, and prediction confidence scores in the Flutter app.
* **AI Chatbot:** Provides further assistance and answers user questions about identified plants and their care.
* **Plant Collection:** Users can save identified plants (including image and fetched data) to their personal collection using Firebase Firestore.
* **User Authentication:** Firebase Authentication for user sign-up and login.
* **Caching:** Backend caches Perenual API responses persistently on disk (`diskcache`) to minimize external calls and improve performance.

## Technology Stack

* **Frontend (Mobile App):**
    * Flutter & Dart
    * Provider (State Management)
    * Firebase SDKs (Auth, Firestore, Storage, Core)
    * `http` (API Communication)
    * `image_picker`
* **Backend (Server):**
    * Python 3.8+
    * FastAPI (Web Framework)
    * Uvicorn (ASGI Server)
    * TensorFlow / Keras (ML Model Inference)
    * Pillow (Image Processing)
    * HTTPX (Async HTTP Client for Perenual)
    * python-dotenv (Environment Variables)
    * DiskCache (Persistent Caching)
* **Machine Learning:**
    * Custom Convolutional Neural Networks (CNNs) trained using TensorFlow/Keras (Training code included in `Training_program/`)
* **External Services:**
    * Perenual API (Plant data enrichment)
    * Firebase (Authentication, Firestore Database, Cloud Storage for user plant images)

## Project Structure
```
CapStone/
├── plantcareai_app/      # Flutter Application Code
│   ├── lib/              # Main Dart code
│   ├── android/          # Android specific files
│   ├── ios/              # iOS specific files
│   ├── ... (other platform folders: web, windows, etc.)
│   └── pubspec.yaml      # Flutter dependencies
├── Server/               # Python Backend (FastAPI)
│   ├── server_main.py    # Main FastAPI application script
│   ├── perenual_client.py # Client for Perenual API with disk caching
│   ├── server_requirements.txt # Python dependencies
│   ├── models/           # Place trained .keras models here >>>>>>
│   │   ├── plant_classifier.keras   (REQUIRED)
│   │   ├── health_classifier.keras  (REQUIRED)
│   │   ├── plant_detector.keras   (REQUIRED)
│   │   └── health_detector.keras  (REQUIRED)
│   ├── mappings/         # JSON mapping files for model outputs
│   │   ├── species_map.json         (REQUIRED)
│   │   └── disease_map.json         (REQUIRED)
│   ├── cache/            # Created automatically by perenual_client.py >>>>
│   ├── .env              # Create this file for Perenual API Key >>>>>>
│   └── serverTest/       # Basic server endpoint tests (test_upload.py)
├── Training_program/     # Scripts & resources for ML model training
│   ├── CNNModel.py       # Model definition class
│   ├── main.py           # Main training script entry point
│   ├── ... (Data processing scripts, logs, etc.)
└── README.md             # This file
```
## Setup & Installation

### Prerequisites

* **Flutter SDK:** Ensure Flutter is installed and configured ([Flutter Installation Guide](https://docs.flutter.dev/get-started/install)). Verify with `flutter doctor`.
* **Python:** Python 3.8+ recommended. Verify with `python --version` or `python3 --version`.
* **Pip:** Python package installer (usually comes with Python).
* **Git:** For cloning the repository (if applicable).
* **Firebase Project:** You **must** have a Firebase project set up. Enable **Authentication** (Email/Password method) and **Firestore** database. **Cloud Storage** is also likely needed if the app saves user plant images. ([Firebase Console](https://console.firebase.google.com/)).
* **Perenual API Key:** Sign up at [Perenual](https://perenual.com/) to get an API key (a free tier is available).

### Backend Setup (`Server/`)

1.  **Navigate to Server Directory:**
    ```bash
    cd path/to/CapStone/Server
    ```
2.  **Create Virtual Environment** (Highly Recommended):
    ```bash
    # Create a virtual environment named 'venv'
    python -m venv venv # Or python3 -m venv venv

    # Activate the virtual environment
    # On Linux/macOS:
    source venv/bin/activate
    # On Windows (Command Prompt):
    # venv\Scripts\activate.bat
    # On Windows (PowerShell):
    # .\venv\Scripts\Activate.ps1
    ```
    *(You should see `(venv)` at the beginning of your terminal prompt)*
3.  **Install Requirements:**
    ```bash
    pip install -r server_requirements.txt
    ```
4.  **Create `.env` File:**
    Create a file named `.env` directly inside the `Server/` directory. Add your Perenual API key to this file:
    ```dotenv
    PERENUAL_API_KEY=your_actual_perenual_api_key_here
    ```
    *(Make sure this file is added to your `.gitignore` if using Git to avoid committing secrets)*
5.  **Place Trained Models:**
    * Create a `models` sub-directory inside `Server/` if it doesn't exist (`mkdir models`).
    * Place your trained TensorFlow/Keras model files (saved in the `.keras` format) inside `Server/models/` with these **exact names**:
        * `plant_classifier.keras`
        * `health_classifier.keras`
    * *(Note: The server currently loads but doesn't explicitly use detector models in the endpoint logic. If you implement that later, add `plant_detector.keras` and `health_detector.keras` here as well.)*
6.  **Verify Mapping Files:**
    * Ensure your `species_map.json` and `disease_map.json` files are present in the `Server/mappings/` directory.
    * The keys in these files should be **strings representing the numerical index** output by your corresponding classifier models (e.g., `"0"`, `"1"`, ...).
    * The structure should match what `server_main.py` expects:
        * `species_map.json`: `{"0": {"name": "...", "family": "...", "genus": "..."}, ...}`
        * `disease_map.json`: `{"0": {"name": "...", "details": "..."}, ...}`
*For more detailed backend configuration, testing, and API documentation, please see [Server/README.md](Server/README.md).*

### Flutter App Setup (`plantcareai_app/`)

1.  **Navigate to App Directory:**
    ```bash
    cd path/to/CapStone/plantcareai_app
    ```
2.  **Firebase Setup:**
    * Follow the official Firebase documentation to **add Firebase to your Flutter app** for both Android and iOS (and other platforms if needed). This involves registering your app bundles/IDs in the Firebase console.
    * Download the configuration files from *your* Firebase project:
        * **Android:** Download `google-services.json` and place it in `plantcareai_app/android/app/`.
        * **iOS:** Download `GoogleService-Info.plist` and place it in `plantcareai_app/ios/Runner/`. Using Xcode is recommended for correctly adding it to the iOS project target.
    * Make sure you have enabled **Authentication** (using the methods your app supports, e.g., Email/Password) and **Firestore** in your Firebase project console. Enable **Storage** if you intend to save user plant images there.
3.  **Get Flutter Dependencies:**
    ```bash
    flutter pub get
    ```
4.  **Configure Backend URL:**
    * Open `plantcareai_app/lib/core/services/prediction_api.dart`.
    * Locate the `uri` variable declaration near the top of the `predictImage` function.
    * **Crucially, update the IP address and port** (`http://35.239.234.106:8000/predict`) to match the address where your Python backend server will be running *and accessible from* your Flutter testing environment (emulator, simulator, or physical device).
        * **Android Emulator:** To reach `localhost:8000` on your host machine, use `http://10.0.2.2:8000`.
        * **iOS Simulator:** Can usually reach `localhost:8000` directly (`http://localhost:8000`).
        * **Physical Device (Same Network):** Use the local network IP address of the machine running the server (e.g., `http://192.168.1.100:8000`). Find this using `ipconfig` (Windows) or `ifconfig`/`ip addr` (macOS/Linux). Ensure your firewall allows connections on port 8000.
        * **Deployed Server:** Use the public IP address or domain name of your deployed server.

## Running the Application

1.  **Start the Backend Server:**
    * Open a terminal/command prompt.
    * Navigate to the `CapStone/Server/` directory.
    * Activate the Python virtual environment (e.g., `source venv/bin/activate`).
    * Run the FastAPI server using Uvicorn:
        ```bash
        python server_main.py
        ```
        *(Alternatively, use `uvicorn server_main:app --host 0.0.0.0 --port 8000 --reload` for development)*
    * Watch the terminal output for confirmation that the server started successfully and that models/maps were loaded. Note any errors.
2.  **Run the Flutter App:**
    * Open a separate terminal/command prompt.
    * Navigate to the `CapStone/plantcareai_app/` directory.
    * Ensure a device is connected or an emulator/simulator is running (`flutter devices`).
    * Run the app:
        ```bash
        flutter run
        ```
    * The app should build and launch. Log in/Sign up and navigate to the plant scanning/prediction feature.

## API Endpoint (`/predict`)

* **Method:** `POST`
* **Request Body:** `multipart/form-data`
    * `file`: The image file of the plant.
* **Success Response (200 OK):**
    * Content-Type: `application/json`
    * Body: A JSON object containing a single key `plant_data`, whose value is another JSON object with prediction and enrichment details. See `server_main.py`'s final response packaging for the exact structure, which includes fields like:
        * `species_id` (int from Perenual or string from local map)
        * `species` (string, best available name)
        * `species_confidence` (float)
        * `health_status` (string: "Healthy", "Unhealthy", "Undetermined")
        * `health_confidence` (float)
        * `disease_name` (string or null)
        * `disease_details` (string or null)
        * `watering_frequency` (string from Perenual or "N/A")
        * `sunlight` (string from Perenual or "N/A")
        * `cycle` (string from Perenual or "N/A")
        * `description` (string from Perenual or default)
* **Error Responses:** Standard FastAPI HTTP error codes (400, 500, etc.) with a JSON body like `{"detail": "Error description"}`. The Flutter `prediction_api.dart` also handles cases where the server returns a 200 OK but includes an error message within the `plant_data` (e.g., `{"plant_data": {"error": "Plant not detected"}}`).

## Caching

The backend uses the `diskcache` library to cache responses from the Perenual API, reducing external calls and potentially speeding up responses for previously identified plants.

* Cache files are stored persistently in the `Server/cache/` directory (created automatically).
* **Search results** (mapping name to potential IDs) are cached for 7 days by default.
* **Plant details** (watering, sunlight, etc., based on ID) are cached for 30 days by default.
* You can manually add/update/delete entries in the *details* cache using a separate Python script that imports and uses the methods provided in `perenual_client.PerenualClient` (e.g., `add_or_update_details_cache`, `get_cached_detail_entry`, `delete_detail_entry`). You would need to create this `manage_cache.py` script yourself if needed.

## Model Training

The `Training_program/` directory contains Python scripts (`main.py`, `CNNModel.py`, various data helpers) and resources used for training the plant species and health classification models. Refer to the scripts within that directory if you need to understand the training process or retrain the models with new data.

## Important Notes

* **CORS Configuration:** Remember to **update the `origins` list** in `server_main.py`'s `CORSMiddleware` configuration before deploying to production. Replace `"*"` with the specific domain(s) where your Flutter web app will be hosted.
* **Firebase Setup:** The Flutter app **will not function correctly** without proper Firebase project setup and the inclusion of the `google-services.json` / `GoogleService-Info.plist` configuration files in the `plantcareai_app/` directory structure.
* **Model Accuracy:** The accuracy of predictions depends entirely on the quality and quantity of data used to train the models in the `Training_program/`.
* **Perenual Matching:** The backend uses the *first* result from Perenual's name search. This might not always be the correct species for ambiguous names.
