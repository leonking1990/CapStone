# Backend Server (FastAPI) - PlantCareAI

This directory contains the Python FastAPI application that serves as the backend for the PlantCareAI project. It handles image processing, machine learning model inference for plant species and health classification, interaction with the Perenual API for data enrichment, and provides an API endpoint for the Flutter application.

## Technology Stack

* **Python 3.8+**
* **FastAPI:** Modern, fast web framework for building APIs.
* **Uvicorn:** ASGI server to run the FastAPI application.
* **TensorFlow/Keras:** For loading and running the trained `.keras` models.
* **Pillow:** For server-side image loading and preprocessing.
* **HTTPX:** For making asynchronous HTTP requests to the Perenual API.
* **DiskCache:** For persistent disk-based caching of Perenual API responses.
* **python-dotenv:** For managing environment variables (like API keys) via a `.env` file.

## Directory Structure
```
Server/
├── server_main.py      # Main FastAPI application, endpoint definitions, startup/shutdown logic
├── perenual_client.py  # Client class for Perenual API interaction with disk caching
├── server_requirements.txt # Python dependencies for the server
├── models/             # REQUIRED: Place trained .keras models here
│   ├── plant_classifier.keras  (REQUIRED)
│   ├── health_classifier.keras (REQUIRED)
│   ├── plant_detector.keras    (REQUIRED)
│   └── health_detector.keras   (REQUIRED)
│   # Optional detector models can be added here if implemented
├── mappings/           # REQUIRED: Place JSON mapping files here
│   ├── species_map.json         (REQUIRED)
│   └── disease_map.json         (REQUIRED)
├── cache/              # --> Automatically created by perenual_client.py for caching
├── .env                # REQUIRED: Create this file for the Perenual API Key
└── serverTest/         # Contains basic endpoint test scripts (e.g., test_upload.py)
```
## Setup

1.  **Navigate to this Directory:**
    ```bash
    cd path/to/CapStone/Server
    ```
2.  **Create Virtual Environment** (Highly Recommended):
    ```bash
    # Create
    python -m venv venv # Or python3 -m venv venv
    # Activate (Linux/macOS)
    source venv/bin/activate
    # Activate (Windows Cmd)
    # venv\Scripts\activate.bat
    # Activate (Windows PowerShell)
    # .\venv\Scripts\Activate.ps1
    ```
3.  **Install Requirements:**
    ```bash
    pip install -r server_requirements.txt
    ```
4.  **Create `.env` File:**
    Create a file named `.env` in this `Server/` directory. Add your Perenual API key:
    ```dotenv
    PERENUAL_API_KEY=your_actual_perenual_api_key_here
    ```
5.  **Place Trained Models:**
    * Create the `models/` subdirectory if it doesn't exist.
    * Place your trained `.keras` files inside `models/` with the exact names:
        * `plant_classifier.keras`
        * `health_classifier.keras`
6.  **Place Mapping Files:**
    * Ensure the `mappings/` subdirectory exists.
    * Place your `species_map.json` and `disease_map.json` files inside `mappings/`.
    * Keys in these files must be strings matching the numerical index output by the models (e.g., `"0"`, `"1"`).
    * Expected structure:
        * `species_map.json`: `{"0": {"name": "...", "family": "...", "genus": "..."}, ...}`
        * `disease_map.json`: `{"0": {"name": "...", "details": "..."}, ...}`

## Running the Server

There are two primary ways to run the server:

1.  **Directly via Python (Uses settings in `server_main.py`)**:
    * Make sure your virtual environment is activated.
    * Run:
        ```bash
        python server_main.py
        ```
    * This will start Uvicorn on `0.0.0.0:8000` by default (see script for args).
    * Use `Ctrl+C` to stop.

2.  **Using Uvicorn Command Line (Good for development/reload)**:
    * Make sure your virtual environment is activated.
    * Run:
        ```bash
        uvicorn server_main:app --host 0.0.0.0 --port 8000 --reload
        ```
    * `server_main:app` refers to the `app` instance inside the `server_main.py` file.
    * `--reload` enables auto-reloading when code changes (requires `watchgod` installation, included in `uvicorn[standard]`).

Check the terminal output for logs indicating successful startup and model/map loading.

## API Endpoints

### `/predict`

* **Method:** `POST`
* **Description:** Accepts an image file, performs plant/health classification, fetches Perenual data, and returns the combined results.
* **Request:** `multipart/form-data`
    * `file`: The image file containing the plant.
* **Success Response (200 OK):** `application/json`
    * A JSON object with a single top-level key `plant_data`.
    * The `plant_data` value is an object containing fields like `species_id`, `species`, `species_confidence`, `health_status`, `health_confidence`, `disease_name`, `disease_details`, `watering_frequency`, `sunlight`, `cycle`, `description`.
    * See the `predict` function in `server_main.py` for the exact structure and potential default values ("N/A", null, etc.).
    * May also return `{"plant_data": {"error": "Plant not detected"}}` if the (optional) plant detector determines no plant is present.
* **Error Responses:**
    * `400 Bad Request`: Invalid input (e.g., no file, bad image format).
    * `500 Internal Server Error`: Error during model prediction, Perenual API interaction, or other server-side processing.
    * `503 Service Unavailable`: Server failed to load essential models/mappings on startup.
    * Error responses typically have a body like `{"detail": "Error description"}`.

### `/`

* **Method:** `GET`
* **Description:** Simple root endpoint for health check or API info.
* **Response:** `application/json`
    * Example: `{"message": "Plant Identifier API is running.", "version": "1.1.0", ...}`

## Configuration

* **Perenual API Key:** Must be set in the `.env` file in this directory (`PERENUAL_API_KEY=...`).
* **Model/Mapping Paths:** Currently hardcoded relative paths in `server_main.py` (`./models/`, `./mappings/`).
* **Cache Path:** Cache files are stored in `./cache/` relative to `perenual_client.py`'s location.
* **Server Host/Port:** Defaults to `0.0.0.0:8000`, can be overridden via command-line arguments when using `python server_main.py --host <ip> --port <num>` or via Uvicorn arguments.

## Caching

The `perenual_client.py` uses the `diskcache` library to store results from Perenual API calls persistently.

* **Location:** `./cache/` subdirectory (created automatically within `Server/`).
* **Caches:**
    * `perenual_search`: Stores results of name searches (`/v2/species-list`). Default expiry: 7 days.
    * `perenual_details`: Stores results of detail lookups (`/v2/species/details/{id}`). Default expiry: 30 days.
* **Manual Management:** The `PerenualClient` class includes methods (`add_or_update_details_cache`, `get_cached_detail_entry`, `delete_detail_entry`) that can be used via a separate Python script (which you would need to create) to manually view, add, update, or remove items from the details cache.

## Testing

A basic test script `serverTest/test_upload.py` is provided. It demonstrates how to send an image file to the `/predict` endpoint.

* **Usage (Example):**
    ```bash
    # Ensure server is running
    python serverTest/test_upload.py path/to/your/plant_image.jpg
    ```

This script may need adjustments based on the final server URL and expected response details.