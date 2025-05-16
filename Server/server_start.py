# server_start.py
import sys
import subprocess
import logging
import os

# --- Basic Logging Setup ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("ServerLauncher")

# --- Configuration ---
MAIN_SERVER_SCRIPT = "server_main.py"
TEST_SERVER_SCRIPT = "server_test.py"
DEFAULT_HOST = "0.0.0.0"
DEFAULT_MAIN_PORT = 8000
DEFAULT_TEST_PORT = 8000 # Use a different default port for the test server

def run_server(script_name: str, host: str, port: int, reload: bool):
    """Runs the appropriate uvicorn command for the given script."""
    if not os.path.exists(script_name):
        logger.error(f"Error: Server script '{script_name}' not found.")
        sys.exit(1)

    # Determine the correct module:app string for uvicorn
    module_name = script_name.replace('.py', '') # Get "server_main" or "server_test"
    app_instance_name = "app" if script_name == MAIN_SERVER_SCRIPT else "app_test"
    app_string = f"{module_name}:{app_instance_name}" # Create "server_main:app" or "server_test:app_test"

    # Build the actual command starting with "uvicorn"
    command = ["uvicorn", app_string, f"--host={host}", f"--port={port}"]
    if reload:
        command.append("--reload")

    logger.info(f"Attempting to start server with command: {' '.join(command)}")
    try:
        # Execute the uvicorn command using subprocess
        process = subprocess.Popen(command) # <-- Runs the constructed uvicorn command
        process.wait()
        logger.info(f"Uvicorn process for '{app_string}' finished with exit code {process.returncode}.")
    except KeyboardInterrupt:
        # (Error handling code as before)
        logger.info(f"\nCtrl+C detected. Stopping server '{app_string}'.")
        if 'process' in locals() and process.poll() is None:
             process.terminate()
             try:
                 process.wait(timeout=5)
             except subprocess.TimeoutExpired:
                 logger.warning(f"Server '{app_string}' did not terminate gracefully, killing.")
                 process.kill()
    except FileNotFoundError:
         logger.error("Error: 'uvicorn' command not found. Make sure uvicorn is installed and in your PATH.")
         sys.exit(1)
    except Exception as e:
        # (Error handling code as before)
        logger.error(f"Failed to run server '{app_string}': {e}", exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    # Simple argument parsing
    args = sys.argv[1:] # Get arguments passed to this script

    mode = "main" # Default mode
    reload_server = False

    if "test" in args:
        mode = "test"
        logger.info("Test mode specified.")
        # Optionally allow --reload in test mode too
        if "--reload" in args:
            reload_server = True
            logger.info("Reload enabled for test server.")
    elif "--reload" in args:
         reload_server = True
         logger.info("Reload enabled for main server.")

    if mode == "test":
        logger.info(f"Starting TEST server ({TEST_SERVER_SCRIPT})...")
        run_server(TEST_SERVER_SCRIPT, DEFAULT_HOST, DEFAULT_TEST_PORT, reload_server)
    else:
        logger.info(f"Starting MAIN server ({MAIN_SERVER_SCRIPT})...")
        run_server(MAIN_SERVER_SCRIPT, DEFAULT_HOST, DEFAULT_MAIN_PORT, reload_server)