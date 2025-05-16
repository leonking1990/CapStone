# server_test.py
import fastapi
import uvicorn
import logging
import json
from fastapi import FastAPI, File, UploadFile, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict, Any, Optional

# --- Basic Logging Setup (Similar to server_main.py) ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__) # Logger for this test server module

# --- Mock Plant Data ---
# Define mock data based on filenames
MOCK_PLANT_DATA: Dict[str, Dict[str, Any]] = {
    # Healthy Plants
    "healthy_rose_1.jpg": {
        "species_id": 101, # Example ID
        "species": "Rose (Simulated)",
        "species_confidence": 0.98,
        "family": "Rosaceae",
        "genus": "Rosa",
        "health_status": "Healthy",
        "health_confidence": 0.99,
        "disease_name": None,
        "disease_details": None,
        "watering_frequency": "Every 2-3 days",
        "sunlight": "Full sun",
        "cycle": "Perennial",
        "description": "A simulated healthy rose.",
    },
    "healthy_tomato_plant.png": {
        "species_id": 102,
        "species": "Tomato (Simulated)",
        "species_confidence": 0.95,
        "family": "Solanaceae",
        "genus": "Solanum",
        "health_status": "Healthy",
        "health_confidence": 0.97,
        "disease_name": None,
        "disease_details": None,
        "watering_frequency": "Daily",
        "sunlight": "Full sun",
        "cycle": "Annual",
        "description": "A simulated healthy tomato plant.",
    },
    "indoor_fern_healthy.jpeg": {
        "species_id": 103,
        "species": "Fern (Simulated)",
        "species_confidence": 0.92,
        "family": "Polypodiaceae", # Example family
        "genus": "Nephrolepis", # Example genus (Boston Fern)
        "health_status": "Healthy",
        "health_confidence": 0.96,
        "disease_name": None,
        "disease_details": None,
        "watering_frequency": "Keep soil moist",
        "sunlight": "Indirect light",
        "cycle": "Perennial",
        "description": "A simulated healthy indoor fern.",
    },
    # Unhealthy Plants
    "unhealthy_basil_mildew.jpg": {
        "species_id": 104,
        "species": "Basil (Simulated)",
        "species_confidence": 0.88,
        "family": "Lamiaceae",
        "genus": "Ocimum",
        "health_status": "Unhealthy",
        "health_confidence": 0.91,
        "disease_name": "Powdery Mildew (Simulated)",
        "disease_details": "Simulated details: White powdery spots on leaves. Improve air circulation and consider fungicide.",
        "watering_frequency": "Water base, avoid wetting leaves",
        "sunlight": "Full sun",
        "cycle": "Annual",
        "description": "A simulated basil plant with powdery mildew.",
    },
    "maple_leaf_spot_issue.png": {
        "species_id": 105,
        "species": "Maple (Simulated)",
        "species_confidence": 0.85,
        "family": "Sapindaceae",
        "genus": "Acer",
        "health_status": "Unhealthy",
        "health_confidence": 0.89,
        "disease_name": "Leaf Spot (Simulated)",
        "disease_details": "Simulated details: Dark spots on leaves. Rake and destroy fallen leaves. Fungicide may be needed in severe cases.",
        "watering_frequency": "Regular watering, especially when young",
        "sunlight": "Full sun to partial shade",
        "cycle": "Perennial",
        "description": "A simulated maple tree with leaf spot.",
    },
}

# --- FastAPI Application Setup (Minimal for Testing) ---
app_test = FastAPI(
    title="Plant Identifier TEST API",
    description="Simulates plant identification based on filename for testing purposes.",
    version="1.0.0-test"
)

# Configure CORS (Allow all for testing convenience)
origins = ["*"]
app_test.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Test Prediction Endpoint ---
@app_test.post("/predict", summary="Simulate Plant Identification")
async def predict_test(request: Request, file: UploadFile = File(..., description="Image file of the plant.")):
    """
    Receives an image file, checks its filename, and returns
    predefined mock data. Simulates processing logs.
    """
    client_host = request.client.host if request.client else "unknown_client"
    filename = file.filename
    content_type = file.content_type

    logger.info(f"[TEST SERVER] Received prediction request from {client_host}. File: '{filename}', Content-Type: {content_type}")

    # Simulate reading the file (optional, could just use filename)
    try:
        # You could optionally read a small amount to simulate processing
        # content = await file.read(1024) # Read first 1KB
        # logger.info(f"[TEST SERVER] Simulated reading {len(content)} bytes from file.")
        logger.info(f"[TEST SERVER] Simulating image preprocessing for '{filename}'.")
        await file.close() # Close the file handle
    except Exception as e:
        logger.error(f"[TEST SERVER] Error simulating file read/processing for '{filename}': {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal server error during test simulation.")

    # --- Simulate Logic: Check Filename ---
    logger.info(f"[TEST SERVER] Checking filename '{filename}' against mock data.")
    mock_data = MOCK_PLANT_DATA.get(filename)

    if mock_data:
        logger.info(f"[TEST SERVER] Found mock data for '{filename}'. Simulating classification and data retrieval.")
        # Simulate steps like in server_main.py logs
        logger.info(f"[TEST SERVER] Local Species Classification (Simulated): Name='{mock_data.get('species')}', Confidence={mock_data.get('species_confidence'):.4f}")
        logger.info(f"[TEST SERVER] Local Health Classification (Simulated): Status='{mock_data.get('health_status')}', Disease='{mock_data.get('disease_name')}', Confidence={mock_data.get('health_confidence'):.4f}")
        logger.info(f"[TEST SERVER] Skipping Perenual search (Test Mode).")
        logger.info(f"[TEST SERVER] Final response payload prepared for client {client_host}: {mock_data}")
        # Return the mock data nested under "plant_data" key
        return {"plant_data": mock_data}
    else:
        logger.warning(f"[TEST SERVER] No mock data found for filename: '{filename}'. Returning 'Unknown'.")
        # Return a default "unknown" response if filename doesn't match
        unknown_response = {
            "species_id": None,
            "species": "Unknown (Test Mode)",
            "species_confidence": 0.0,
            "family": None,
            "genus": None,
            "health_status": "Undetermined",
            "health_confidence": 0.0,
            "disease_name": None,
            "disease_details": "No matching test data for this filename.",
            "watering_frequency": "N/A",
            "sunlight": "N/A",
            "cycle": "N/A",
            "description": "No mock data available for this filename in test mode.",
        }
        return {"plant_data": unknown_response}

# --- Root Endpoint (for health check/info) ---
@app_test.get("/", summary="API Root/Health Check (Test Mode)")
async def read_root_test():
    logger.info("[TEST SERVER] Root endpoint '/' accessed.")
    return {
        "message": "Plant Identifier TEST API is running.",
        "mode": "simulation",
        "info": "This server returns mock data based on filenames.",
    }

# --- Main Execution Block (for running with `python server_test.py`) ---
if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Run the Plant Identification TEST API server using Uvicorn.")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host address.")
    parser.add_argument("--port", type=int, default=8001, help="Port number (using a different default port).") # Different port than main
    parser.add_argument("--reload", action="store_true", help="Enable auto-reload mode.")
    args = parser.parse_args()

    log_level = "debug" if args.reload else "info"

    logger.info(f"[TEST SERVER] Starting Uvicorn test server on {args.host}:{args.port}")
    logger.info(f"[TEST SERVER] Auto-reload: {'Enabled' if args.reload else 'Disabled'}")
    logger.info(f"[TEST SERVER] Uvicorn log level: {log_level}")

    # Run the FastAPI app using Uvicorn
    uvicorn.run(
        "server_test:app_test", # Point to the app instance in *this* file
        host=args.host,
        port=args.port,
        reload=args.reload,
        log_level=log_level
    )