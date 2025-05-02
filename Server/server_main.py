import fastapi
import uvicorn
import io
import json
import numpy as np
import logging
import os
import asyncio # Import asyncio for thread execution
from PIL import Image
from fastapi import FastAPI, File, UploadFile, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict, Any, Tuple, Optional
import tensorflow as tf
from pathlib import Path

# --- Import the Perenual client instance ---
# This assumes perenual_client.py is in the same directory or Python path
from perenual_client import perenual_client

# --- Basic Logging Setup ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__) # Logger for this main server module

# --- Global Variables / Application State ---
# Use a dictionary to store loaded models and mappings for cleaner state management
app_state: Dict[str, Any] = {
    "models": {},
    "mappings": {},
}

# --- Configuration ---
MODEL_DIR = Path("./models")
MAPPING_DIR = Path("./mappings")
DEFAULT_IMAGE_SIZE: Tuple[int, int] = (224, 224) # Standard size for many image models

# --- Model and Mapping Loading Functions ---

def load_tf_model(model_filename: str) -> Optional[tf.keras.Model]:
    """Loads a TensorFlow/Keras model safely from the MODEL_DIR."""
    model_path = MODEL_DIR / f"{model_filename}.keras"
    if not model_path.is_file():
        logger.error(f"Model file not found: {model_path.resolve()}")
        return None
    try:
        logger.info(f"Attempting to load model from: {model_path.resolve()}")
        # Loading Keras models can be resource-intensive
        model = tf.keras.models.load_model(str(model_path))
        logger.info(f"✅ Model '{model_filename}' loaded successfully.")
        return model
    except Exception as e:
        logger.error(f"❌ Error loading model '{model_filename}' from {model_path.resolve()}: {e}", exc_info=True)
        return None

def load_json_mapping(mapping_filename: str) -> Optional[Dict]:
    """Loads a JSON mapping file safely from the MAPPING_DIR."""
    mapping_path = MAPPING_DIR / mapping_filename
    if not mapping_path.is_file():
        logger.error(f"Mapping file not found: {mapping_path.resolve()}")
        return None
    try:
        logger.info(f"Attempting to load mapping file: {mapping_path.resolve()}")
        with open(mapping_path, 'r', encoding='utf-8') as f: # Specify encoding
            mapping_data = json.load(f)
        logger.info(f"✅ Mapping file '{mapping_filename}' loaded successfully.")
        return mapping_data
    except json.JSONDecodeError as e:
        logger.error(f"❌ Error decoding JSON from '{mapping_filename}': {e}", exc_info=True)
        return None
    except Exception as e:
        logger.error(f"❌ Error loading mapping file '{mapping_filename}': {e}", exc_info=True)
        return None

# --- FastAPI Application Setup ---
app = FastAPI(
    title="Plant Identifier API",
    description="Identifies plant species and health from images, enriched with Perenual data.",
    version="1.1.0" # Increment version
)

# Configure CORS (Cross-Origin Resource Sharing)
# Allows requests from your Flutter app's origin
# Be more specific in production!
origins = [
    "http://localhost", # Allow local development origins
    "http://localhost:8080", # Common Flutter debug origin
    # Add your Flutter web app's deployed origin here
    # "https://your-flutter-app-domain.com", # Example production origin future project
    "*", # TEMPORARY: Allow all for initial testing, REMOVE/RESTRICT for production
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"], # Allows all methods (GET, POST, etc.)
    allow_headers=["*"], # Allows all headers
)


# --- FastAPI Event Handlers ---

@app.on_event("startup")
async def startup_event():
    """Loads models and mappings when the server starts."""
    logger.info("🚀 Server starting up. Loading models and mappings...")

    # Verify directories exist
    if not MODEL_DIR.is_dir():
        logger.error(f"Models directory not found: {MODEL_DIR.resolve()}")
    if not MAPPING_DIR.is_dir():
        logger.error(f"Mappings directory not found: {MAPPING_DIR.resolve()}")

    # --- Load Models ---
    # Store loaded models in the app_state dictionary
    app_state["models"]["plant_detector"] = load_tf_model("plant_detector") 
    app_state["models"]["health_detector"] = load_tf_model("health_detector") 
    app_state["models"]["plant_classifier"] = load_tf_model("plant_classifier") # Essential
    app_state["models"]["health_classifier"] = load_tf_model("health_classifier") # Essential

    # --- Load Mappings ---
    app_state["mappings"]["species_map"] = load_json_mapping("species_map.json") # Essential
    app_state["mappings"]["disease_map"] = load_json_mapping("disease_map.json") # Essential

    # --- Check Essential Components ---
    # Verify that critical models and maps were loaded successfully
    essential_components = {
        "Plant Classifier": app_state["models"]["plant_classifier"],
        "Health Classifier": app_state["models"]["health_classifier"],
        "Species Map": app_state["mappings"]["species_map"],
        "Disease Map": app_state["mappings"]["disease_map"],
    }
    all_essential_loaded = all(essential_components.values())

    if not all_essential_loaded:
        missing = [name for name, comp in essential_components.items() if not comp]
        logger.critical(f"🔥 Critical components failed to load: {', '.join(missing)}. API may not function correctly.")
        # Consider raising an exception or exiting if core functionality is impossible
        # raise RuntimeError(f"Failed to load essential components: {', '.join(missing)}")
    else:
        logger.info("✅ All essential models and mappings loaded successfully.")

    # --- Perenual Client Check ---
    # The client is initialized on import, just check if the API key was found
    if not perenual_client.api_key:
         logger.warning("Perenual API key was not found by the client. Perenual data enrichment will be disabled.")
    else:
         logger.info("Perenual client is initialized and API key is present.")


@app.on_event("shutdown")
async def shutdown_event():
    """Closes resources cleanly on server shutdown."""
    logger.info("🔌 Server shutting down.")
    # Close the Perenual client's disk caches
    perenual_client.close_caches()
    logger.info("Perenual caches closed.")
    # Add any other cleanup needed here


# --- Helper Functions ---

def preprocess_image(image_bytes: bytes, target_size: Tuple[int, int] = DEFAULT_IMAGE_SIZE) -> Optional[np.ndarray]:
    """Loads image from bytes, converts to RGB, resizes, normalizes, and adds batch dimension."""
    try:
        image = Image.open(io.BytesIO(image_bytes)).convert('RGB')
        # Optional: Add check for minimum image dimensions if needed
        # if image.width < 50 or image.height < 50: logger.warning(...)

        image = image.resize(target_size)
        image_array = np.array(image, dtype=np.float32) / 255.0 # Normalize to [0, 1]
        # Add batch dimension: (height, width, channels) -> (1, height, width, channels)
        return np.expand_dims(image_array, axis=0)
    except Exception as e:
        logger.error(f"Error preprocessing image: {e}", exc_info=True)
        return None

async def run_prediction(model_name: str, processed_image: np.ndarray) -> Optional[np.ndarray]:
    """
    Runs prediction using a loaded model. Handles potential model unavailability
    and runs the prediction in a separate thread to avoid blocking the event loop.
    """
    model = app_state["models"].get(model_name)
    if model is None:
        logger.error(f"Prediction failed: Model '{model_name}' is not loaded or available.")
        return None
    if processed_image is None:
        logger.error(f"Prediction failed for '{model_name}': Invalid processed image input (None).")
        return None

    try:
        # Run synchronous TF/Keras predict in a thread pool executor
        # This prevents blocking FastAPI's async event loop
        loop = asyncio.get_running_loop()
        predictions = await loop.run_in_executor(None, model.predict, processed_image)
        # Example: predictions shape might be (1, num_classes)
        # logger.debug(f"Raw predictions shape from '{model_name}': {predictions.shape}") # Optional debug log
        return predictions
    except Exception as e:
        logger.error(f"Error during prediction with model '{model_name}': {e}", exc_info=True)
        return None


# --- Main Prediction Endpoint ---
@app.post("/predict", summary="Identify Plant Species and Health")
async def predict(request: Request, file: UploadFile = File(..., description="Image file of the plant.")):
    """
    Receives an image file, processes it through local classification models,
    queries the Perenual API (using cached client) for enrichment,
    and returns a combined JSON response detailing the plant's species,
    health status, and care information.
    """
    client_host = request.client.host if request.client else "unknown_client"
    logger.info(f"Received prediction request from {client_host}. File: '{file.filename}', Content-Type: {file.content_type}")

    # 1. Read and Preprocess Image
    image_bytes = await file.read()
    if not image_bytes:
         logger.error("Received empty file from client.")
         raise HTTPException(status_code=400, detail="Empty file uploaded.")

    processed_image = preprocess_image(image_bytes, target_size=DEFAULT_IMAGE_SIZE)
    if processed_image is None:
        logger.error("Image preprocessing failed (invalid format or error).")
        raise HTTPException(status_code=400, detail="Invalid or unsupported image format/content.")

    # --- 2. Run Local Models ---
    # Initialize result variables
    species_id_result: Optional[str] = None # Local map key (string)
    species_name_result: str = "Unknown"
    species_confidence: float = 0.0
    initial_species_name_result: str = "Unknown" # Name before Perenual check

    health_status: str = "Undetermined"
    disease_name_result: Optional[str] = None # Null if healthy
    disease_details_result: Optional[str] = None # Null if healthy
    health_confidence: float = 0.0

     # --- Plant Classification ---
    plant_classifier = app_state["models"].get("plant_classifier")
    species_map = app_state["mappings"].get("species_map")

    # Initialize defaults
    species_id_result: Optional[str] = None # Local map key (string) or None
    species_name_result: str = "Unknown"
    species_confidence: float = 0.0
    initial_species_name_result: str = "Unknown" # Name before Perenual check
    # Initialize family/genus as None since they are not in this map format
    family_result: Optional[str] = None
    genus_result: Optional[str] = None

    if plant_classifier and species_map:
        species_predictions = await run_prediction("plant_classifier", processed_image)
        if species_predictions is not None and species_predictions.size > 0:
            pred_vector = species_predictions[0]
            predicted_class_index = np.argmax(pred_vector)
            species_confidence = float(pred_vector[predicted_class_index])
            plant_class_key = str(predicted_class_index) # Map key is string index

            # --- CORRECTED LOGIC ---
            # Directly get the species name string from the map
            species_name = species_map.get(plant_class_key)

            if species_name: # Check if the key existed and returned a name string
                species_id_result = plant_class_key # Use local map key as fallback ID
                species_name_result = species_name    # Use the name directly from the map
                initial_species_name_result = species_name_result # Store this name for Perenual search
                # Family and Genus are not available in this map format
                family_result = None
                genus_result = None
                logger.info(f"Local Species Classification: ID='{species_id_result}', Name='{species_name_result}', Confidence={species_confidence:.4f}")
            else:
                # The key was not found in the species map
                logger.warning(f"Species map key '{plant_class_key}' not found in species_map.json.")
                species_name_result = "Unknown Species in Map"
                initial_species_name_result = species_name_result
            # --- END CORRECTED LOGIC ---

        else:
            logger.error("Plant classification model prediction failed or returned empty.")
            species_name_result = "Classification Failed"
            initial_species_name_result = species_name_result
    else:
        logger.error("Plant classifier model or species map not loaded. Cannot classify species.")
        species_name_result = "Setup Error"
        initial_species_name_result = species_name_result

    # --- Health Classification ---
    health_classifier = app_state["models"].get("health_classifier")
    disease_map = app_state["mappings"].get("disease_map")

    # Initialize defaults
    health_status: str = "Undetermined"
    disease_name_result: Optional[str] = None # Null if healthy or undetermined
    disease_details_result: Optional[str] = None # Details are not in this map format
    health_confidence: float = 0.0

    if health_classifier and disease_map:
        health_predictions = await run_prediction("health_classifier", processed_image)
        if health_predictions is not None and health_predictions.size > 0:
            pred_vector = health_predictions[0]
            predicted_class_index = np.argmax(pred_vector)
            health_confidence = float(pred_vector[predicted_class_index])
            disease_class_key = str(predicted_class_index) # Map key is string index

            # --- CORRECTED LOGIC ---
            # Directly get the disease name string from the map
            disease_name = disease_map.get(disease_class_key)

            if disease_name: # Check if the key existed and returned a name string
                # Convention: If name contains "healthy", status is Healthy
                if "healthy" in disease_name.lower():
                    health_status = "Healthy"
                    disease_name_result = None # Explicitly no disease name if healthy
                    disease_details_result = None
                else:
                    health_status = "Unhealthy"
                    disease_name_result = disease_name # Use the name directly from the map
                    disease_details_result = "Details not available in local map." # Set default details

                logger.info(f"Local Health Classification: Status='{health_status}', Disease='{disease_name_result}', Confidence={health_confidence:.4f}")
            else:
                 # The key was not found in the disease map
                 logger.warning(f"Disease map key '{disease_class_key}' not found in disease_map.json.")
                 health_status = "Undetermined (Map Key Error)"
            # --- END CORRECTED LOGIC ---

        else:
             logger.error("Health classification model prediction failed or returned empty.")
             health_status = "Undetermined (Model Failed)"
    else:
        logger.error("Health classifier model or disease map not loaded. Cannot classify health.")
        health_status = "Undetermined (Setup Error)"

    # The rest of the /predict function continues...
    # Note that disease_details_result will now be None or the default string,
    # as details aren't available in your current disease_map.json format.


    # --- 3. Perenual API Interaction (using the cached client) ---
    perenual_fetched_data = {} # Store data retrieved from Perenual details
    perenual_species_id : Optional[int] = None # Use Perenual's integer ID if found

    # Only query Perenual if initial classification was reasonably confident and valid
    # Example threshold: confidence > 0.5 and name is not an error/unknown string
    CONFIDENCE_THRESHOLD = 0.50
    should_query_perenual = (
        species_confidence >= CONFIDENCE_THRESHOLD and
        initial_species_name_result not in ["Unknown", "Classification Failed", "Unknown Species in Map", "Setup Error"]
    )

    if should_query_perenual:
        logger.info(f"Attempting Perenual search for: '{initial_species_name_result}' (Confidence: {species_confidence:.4f})")
        # Use the Perenual client's search method
        search_results = await perenual_client.search_species_by_name(initial_species_name_result)

        # search_results can be None (failure) or list (potentially empty)
        if isinstance(search_results, list) and search_results:
            # Found results, take the first one as best match
            first_result = search_results[0]
            perenual_species_id = first_result.get('id') # This should be an integer
            perenual_common_name = first_result.get('common_name') # Might be empty

            if perenual_species_id and isinstance(perenual_species_id, int):
                # Refine species name if Perenual provides a common name
                if perenual_common_name:
                    species_name_result = perenual_common_name # Prefer Perenual's common name
                logger.info(f"Perenual search successful. Found ID: {perenual_species_id}. Refined Name: '{species_name_result}'")

                # Fetch details using the Perenual ID
                logger.info(f"Attempting Perenual details fetch for ID: {perenual_species_id}")
                details_data = await perenual_client.get_species_details(perenual_species_id)

                if details_data and isinstance(details_data, dict):
                    logger.info(f"Perenual details fetched successfully for ID: {perenual_species_id}")
                    # Extract relevant details using .get() for safety
                    perenual_fetched_data['watering_frequency'] = details_data.get("watering")
                    sunlight_list = details_data.get("sunlight", []) # Expect list
                    perenual_fetched_data['sunlight'] = ', '.join(sl for sl in sunlight_list if isinstance(sl, str)) if isinstance(sunlight_list, list) else None
                    perenual_fetched_data['cycle'] = details_data.get("cycle")
                    perenual_fetched_data['description'] = details_data.get("description")
                    # Add other fields if needed (e.g., family, origin)
                else:
                    logger.warning(f"Failed to fetch Perenual details for ID: {perenual_species_id} (API error, 404, or empty response). Will use local data only.")
            else:
                 logger.warning(f"Perenual search result lacked a valid integer 'id'. First result: {first_result}")
                 # Keep local classification if ID is missing/invalid
        elif isinstance(search_results, list) and not search_results:
             logger.info(f"Perenual search for '{initial_species_name_result}' returned no results.")
             # Keep local classification if Perenual finds nothing
        else: # search_results is None (indicates API/network error)
             logger.warning(f"Perenual search for '{initial_species_name_result}' failed (returned None). Check client logs.")
             # Keep local classification if Perenual search fails
    else:
         logger.info(f"Skipping Perenual search for '{initial_species_name_result}' due to low confidence ({species_confidence:.4f}) or invalid initial name.")


    # --- 4. Package Final Response ---
    # Decide which species ID to return: Perenual's integer ID if available, otherwise local string key, or None
    final_species_id = perenual_species_id if perenual_species_id else species_id_result

    # Build the response dictionary matching Flutter app's expected structure
    plant_data_response = {
        # Core Identification
        "species_id": final_species_id, # Can be int (Perenual) or str (local) or None
        "species": species_name_result, # Best available name (Perenual common_name or local map name)
        "species_confidence": round(species_confidence, 4),
        "family": family_result, 
        "genus": genus_result,   

        # Health Status
        "health_status": health_status,
        "health_confidence": round(health_confidence, 4),
        "disease_name": disease_name_result, # From local map
        "disease_details": disease_details_result, # From local map

        # Perenual Enrichment Data (use fetched data or defaults)
        "watering_frequency": perenual_fetched_data.get("watering_frequency") or "N/A",
        "sunlight": perenual_fetched_data.get("sunlight") or "N/A",
        "cycle": perenual_fetched_data.get("cycle") or "N/A",
        "description": perenual_fetched_data.get("description") or "No description available.",
    }

    logger.info(f"Final response payload prepared for client {client_host}: {plant_data_response}")

    # Return the data nested under "plant_data" key. FastAPI handles JSON encoding.
    # The Flutter client should expect response.body to be a JSON string
    # representing {"plant_data": {...}}, and decode it ONCE.
    return {"plant_data": plant_data_response}


# --- Root Endpoint (for health check/info) ---
@app.get("/", summary="API Root/Health Check")
async def read_root():
    logger.info("Root endpoint '/' accessed.")
    # Provide basic API status info
    return {
        "message": "Plant Identifier API is running.",
        "version": app.version,
        "docs_url": "/docs",
        "redoc_url": "/redoc"
    }

# --- Main Execution Block (for running with `python server_main.py`) ---
if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Run the Plant Identification API server using Uvicorn.")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host address to bind the server to.")
    parser.add_argument("--port", type=int, default=8000, help="Port number to run the server on.")
    parser.add_argument("--reload", action="store_true", help="Enable auto-reload mode for development (requires 'watchgod').")
    args = parser.parse_args()

    # Determine log level for Uvicorn based on reload flag or environment variable
    log_level = "debug" if args.reload else "info"

    logger.info(f"Starting Uvicorn server on {args.host}:{args.port}")
    logger.info(f"Auto-reload: {'Enabled' if args.reload else 'Disabled'}")
    logger.info(f"Uvicorn log level: {log_level}")

    # Run the FastAPI app using Uvicorn programmatically
    uvicorn.run(
        "server_main:app", # App instance location: 'app' in 'server_main.py'
        host=args.host,
        port=args.port,
        reload=args.reload, # Enable/disable auto-reload
        log_level=log_level # Control Uvicorn's verbosity
    )