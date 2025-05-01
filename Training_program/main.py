# --- Standard Library Imports ---
import os
import json
import warnings
import re
from datetime import datetime

# --- Third-Party Imports ---
import tensorflow as tf
# import logging # Uncomment if needed later

# --- Early TensorFlow/System Configuration ---
# GPU Memory Growth (Run this early!)
# This is important for TensorFlow to avoid allocating all GPU memory at once.
# It allows TensorFlow to allocate memory as needed, current server (Chico State CSCIGPU) is used by multiple users.
# This is especially useful in shared environments and/or when running or training multiple models.
# Note to self: inform faculty so students don’t unintentionally over-allocate GPU memory.
gpu_devices = tf.config.list_physical_devices('GPU')
if gpu_devices:
    print(f"Found GPU(s): {gpu_devices}")
    try:
        for gpu in gpu_devices:
            tf.config.experimental.set_memory_growth(gpu, True)
        print("   Memory growth enabled for GPU(s).")
    except RuntimeError as e:
        print(f"Error setting memory growth (might be too late): {e}")
else:
    print("No GPU found by TensorFlow.")


# Set TF log level (0=all, 1=no INFO, 2=no WARN, 3=no ERROR)
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

# Filter specific warnings (optional)
warnings.filterwarnings("ignore", category=UserWarning, module="keras")

# --- Local Application Imports ---
# Ensure these paths are correct for your project structure
from CNNModel import PlantCNNModel
from tf_data_pipeline_new import create_tf_dataset
from tensorflow.keras.mixed_precision import set_global_policy

# Mixed Precision
set_global_policy('mixed_float16')
print("Mixed precision 'mixed_float16' enabled.")

from tensorflow.keras.applications.efficientnet_v2 import preprocess_input as efficientnet_preprocess_input



# --- Configuration Constants ---
# Modify paths as needed for your environment

# Base directory for Plant Classifier data
BASE_DATA_DIR_PLANT_CLASSIFIER = "/research/New Plant Diseases Dataset(Augmented)/New Plant Diseases Dataset(Augmented)"
TRAIN_SUBDIR_PLANT_CLASSIFIER = "train"
VAL_SUBDIR_PLANT_CLASSIFIER = "valid"

# Base directory for Health Detector data
BASE_DATA_DIR_HEALTH_DETECTOR = "/research/New Plant Diseases Dataset(Augmented)/New Plant Diseases Dataset(Augmented)"
TRAIN_DIR_HEALTH_DETECTOR = os.path.join(
    BASE_DATA_DIR_HEALTH_DETECTOR, 'train')
VALID_DIR_HEALTH_DETECTOR = os.path.join(
    BASE_DATA_DIR_HEALTH_DETECTOR, 'valid')

# Common constants
MODELS_DIR = "models"
LOGS_DIR = "logs"  # Renamed from BASE_LOG_DIR for clarity
BATCH_SIZE = 256  # Adjust as needed
# Will be saved in the run-specific model dir
CLASS_INDICES_FILENAME = 'class_indices.json'

# --- Helper Functions ---
def scale_0_1(image):
    """Scales image pixel values to the [0, 1] range."""
    # Ensure image is float32 before division
    return tf.cast(image, tf.float32) / 255.0

# --- Main Function ---
def main():
    """
    Main function to handle dataset preparation, model building/loading,
    training, and deployment for various plant-related models.
    """
    print("--- Starting Plant AI Training Program ---\n")

    # --- Initial Checks ---
    print("TensorFlow Version:", tf.__version__)
    print("GPU Available:", tf.config.list_physical_devices('GPU'))

    # --- Model Type Selection ---
    print("Select the type of model to work with:")
    model_options = {
        "1": "PlantClassifier",
        "2": "PlantDetector",
        "3": "HealthDetector",
        "4": "HealthClassifier"
    }
    for key, value in model_options.items():
        print(f"  {key}: {value}")

    selected_model_type = None
    while selected_model_type is None:
        choice = input("Enter the number for the model type: ").strip()
        selected_model_type = model_options.get(choice)
        if selected_model_type is None:
            print("❌ Invalid choice. Please enter a number from the list.")

    print(f"\nSelected Model Type: {selected_model_type}")

    indices_NAME = selected_model_type + '_' + CLASS_INDICES_FILENAME
    save_path = os.path.join("models", selected_model_type, indices_NAME)
    save_dir = os.path.join("models", selected_model_type)

    # --- Handle Unimplemented Models ---
    if selected_model_type in ["PlantDetector",]:
        print(f"\n--- {selected_model_type} ---")
        print("❌ Not Implemented Yet.")
        exit(0)

    # --- Build/Load Choice ---
    model_choice = ""
    while model_choice not in ["build", "load"]:
        model_choice = input(
            "Build a new model or load an existing one? (build/load): ").strip().lower()

    use_transfer_learning = False  # Default for custom models or health detector
    if model_choice == "build":
        # Ask about transfer learning only if relevant (e.g., for PlantClassifier)
        # You might customize this prompt based on selected_model_type if needed
        if selected_model_type == "PlantClassifier" or selected_model_type == "HealthClassifier":
            model_type_choice = ""
            while model_type_choice not in ["custom", "pretrained"]:
                model_type_choice = input(
                    "Use custom CNN or pretrained transfer model? (custom/pretrained): ").strip().lower()
            use_transfer_learning = (model_type_choice == "pretrained")
        # Add similar prompts here if HealthDetector build also has custom/pretrained option

    # --- Dataset Preparation ---
    print("\n--- Preparing Datasets ---")

    # Initialize variables to store dataset info
    train_data = None
    val_data = None
    class_names = None
    class_indices = None
    class_weight_dict = None
    num_classes_found = 0
    preprocessing_function_to_use = None

    # ===========================
    # === PlantClassifier Setup ===
    # ===========================
    if selected_model_type == "PlantClassifier":
        print(f"Preparing data for {selected_model_type}...")
        train_dir = os.path.join(
            BASE_DATA_DIR_PLANT_CLASSIFIER, TRAIN_SUBDIR_PLANT_CLASSIFIER)
        val_dir = os.path.join(
            BASE_DATA_DIR_PLANT_CLASSIFIER, VAL_SUBDIR_PLANT_CLASSIFIER)

        if not os.path.exists(train_dir) or not os.path.exists(val_dir):
            print(
                f"❌ ERROR: PlantClassifier Training ({train_dir}) or Validation ({val_dir}) directory not found.")
            exit(1)

        # Choose preprocessing based on transfer learning choice
        if use_transfer_learning:
            preprocessing_function_to_use = efficientnet_preprocess_input
            print("Using EfficientNetV2 preprocessing for PlantClassifier.")
        else:
            preprocessing_function_to_use = scale_0_1
            print("Using simple 0-1 scaling preprocessing for PlantClassifier.")

        print("\tCreating Training dataset...")
        train_data, class_names, class_indices, class_weight_dict = create_tf_dataset(
            dir_path=train_dir,
            batch_size=BATCH_SIZE,
            preprocessing_fn=preprocessing_function_to_use,
            model=selected_model_type,  # Pass model type
            is_training=True,
            class_names=None,  # Infer from directory
            return_labels_weights=True,
        )

        print('\tCreating Validation dataset...')
        val_data, _, _, _ = create_tf_dataset(
            dir_path=val_dir,
            batch_size=BATCH_SIZE,
            preprocessing_fn=preprocessing_function_to_use,
            model=selected_model_type,  # Pass model type
            is_training=False,
            class_names=class_names,  # Use same classes as training
            return_labels_weights=False
        )
        num_classes_found = len(class_names)
        print(
            f"\t\tPlantClassifier data created. Found {num_classes_found} classes.")

    # =============================
    # === PlantClassifier Setup ===
    # =============================
    elif selected_model_type == "HealthClassifier":
        print(f"Preparing data for {selected_model_type}...")
        train_dir = os.path.join(
            BASE_DATA_DIR_PLANT_CLASSIFIER, TRAIN_SUBDIR_PLANT_CLASSIFIER)
        val_dir = os.path.join(
            BASE_DATA_DIR_PLANT_CLASSIFIER, VAL_SUBDIR_PLANT_CLASSIFIER)

        if not os.path.exists(train_dir) or not os.path.exists(val_dir):
            print(
                f"❌ ERROR: PlantClassifier Training ({train_dir}) or Validation ({val_dir}) directory not found.")
            exit(1)

        # Choose preprocessing based on transfer learning choice
        if use_transfer_learning:
            preprocessing_function_to_use = efficientnet_preprocess_input
            print("Using EfficientNetV2 preprocessing for PlantClassifier.")
        else:
            preprocessing_function_to_use = scale_0_1
            print("Using simple 0-1 scaling preprocessing for PlantClassifier.")

        print("\tCreating Training dataset...")
        train_data, class_names, class_indices, class_weight_dict = create_tf_dataset(
            dir_path=train_dir,
            batch_size=BATCH_SIZE,
            preprocessing_fn=preprocessing_function_to_use,
            model=selected_model_type,  # Pass model type
            is_training=True,
            class_names=None,  # Infer from directory
            return_labels_weights=True,
        )

        print('\tCreating Validation dataset...')
        val_data, _, _, _ = create_tf_dataset(
            dir_path=val_dir,
            batch_size=BATCH_SIZE,
            preprocessing_fn=preprocessing_function_to_use,
            model=selected_model_type,  # Pass model type
            is_training=False,
            class_names=class_names,  # Use same classes as training
            return_labels_weights=False
        )
        num_classes_found = len(class_names)
        print(
            f"\t\tPlantClassifier data created. Found {num_classes_found} classes.")

    # ============================
    # === HealthDetector Setup ===
    # ============================
    elif selected_model_type == "HealthDetector":
        print(f"Preparing data for {selected_model_type}...")
        train_dir = TRAIN_DIR_HEALTH_DETECTOR
        val_dir = VALID_DIR_HEALTH_DETECTOR  # Corrected variable name

        if not os.path.exists(train_dir) or not os.path.exists(val_dir):
            print(
                f"❌ ERROR: HealthDetector Training ({train_dir}) or Validation ({val_dir}) directory not found.")
            exit(1)

        # Define preprocessing for HealthDetector (adjust if needed)
        # Assuming simple scaling for now. Change to efficientnet_preprocess_input
        # if using transfer learning for HealthDetector.
        preprocessing_function_to_use = scale_0_1
        print("Using simple 0-1 scaling preprocessing for HealthDetector.")

        print("\tCreating Training dataset...")
        # NOTE: Assuming train_dir and val_dir are separate, dedicated directories.
        # Therefore, we do NOT pass 'subset' or 'validation_split' here,
        # allowing image_dataset_from_directory to load the whole directory.
        train_data, class_names, class_indices, class_weight_dict = create_tf_dataset(
            dir_path=train_dir,
            batch_size=BATCH_SIZE,  # Use the global BATCH_SIZE
            preprocessing_fn=preprocessing_function_to_use,
            model=selected_model_type,  # Pass model type
            is_training=True,
            return_labels_weights=True,
            # subset=None, validation_split=None <-- Do not pass if dir_path is dedicated training data
        )

        print('\tCreating Validation dataset...')
        val_data, _, _, _ = create_tf_dataset(
            dir_path=val_dir,  # Use the dedicated validation directory
            batch_size=BATCH_SIZE,
            preprocessing_fn=preprocessing_function_to_use,
            model=selected_model_type,  # Pass model type
            is_training=False,
            return_labels_weights=False,
            # subset=None, validation_split=None <-- Do not pass if dir_path is dedicated validation data
        )
        # Should be 2 ('healthy', 'unhealthy')
        num_classes_found = len(class_names)
        print(
            f"\t\tHealthDetector data created. Found {num_classes_found} classes: {class_names}")

    # --- Model Handling (Build or Load) ---
    print("\n--- Model Setup ---")
    # Rename variable? Or keep generic? Let's keep it for now.
    plant_classifier: PlantCNNModel = None

    if model_choice == "build":
        print(f"\nBuilding the {selected_model_type} model...")
        try:
            # Pass necessary info based on selected model type
            # Note: CNNModel class might need adaptation if HealthDetector requires
            # a different architecture or output layer size (num_classes=2).
            # Assuming CNNModel can handle num_classes parameter correctly.
            plant_classifier = PlantCNNModel(
                num_classes=num_classes_found,  # Pass the number of classes found
                class_indices=class_indices,  # Pass the corresponding indices
                use_pretrained=use_transfer_learning,  # Pass transfer learning choice
                # input_shape can be omitted if using default (224, 224, 3)
            )
            plant_classifier.get_summary()  # Display model summary
        except Exception as e:
            print(f"❌ Error building model: {e}")
            exit(1)

        # --- Training ---
        train_choice = ""
        while train_choice not in ["yes", "y", "no", "n"]:
            train_choice = input("Start training? (yes/no): ").strip().lower()

        if train_choice in ["yes", "y"]:
            while True:
                try:
                    epochs_input = input(
                        f"Enter number of epochs to train (e.g., 50): ")
                    epochs_to_train = int(epochs_input)
                    if epochs_to_train > 0:
                        break
                    else:
                        print("❌ Please enter a positive number of epochs.")
                except ValueError:
                    print("❌ Invalid input. Please enter an integer.")

            print('\n--- Training Initiated ---')
            plant_classifier.train(
                train_generator=train_data,
                validation_generator=val_data,
                class_weight_dict=class_weight_dict,
                epochs=epochs_to_train,
                base_log_dir=LOGS_DIR,  # Use updated constant
                base_model_dir=MODELS_DIR,  # Use updated constant
                model_name=selected_model_type,  # Pass model type for saving
            )
            # Checkpointing saves the best/latest model during training.
        else:
            print("Exiting without training.")
            exit(0)

    elif model_choice == "load":
        print("\nLoading existing model...")
        # --- Select Model Checkpoint ---
        # This function needs to be aware of the selected_model_type
        # or the MODELS_DIR structure needs to reflect the model type.
        # For now, assuming select_model_checkpoint looks in the general MODELS_DIR.
        # You might need to modify select_model_checkpoint or the directory structure
        # if models for different types are stored separately.
        model_load_path, selected_dir_path = select_model_checkpoint(
            MODELS_DIR)
        if not model_load_path:
            print("❌ No model selected or found. Exiting.")
            exit(1)

        # --- Load Class Indices ---
        # CRITICAL: Load indices corresponding to the *loaded model*,
        # which should be saved in the same directory as the model checkpoint.

        indices_load_path = os.path.join(
            selected_dir_path, CLASS_INDICES_FILENAME)
        print(f"\tAttempting to load class indices from: {indices_load_path}")

        loaded_indices = None
        if os.path.exists(indices_load_path):
            try:
                with open(indices_load_path, 'r') as f:
                    loaded_indices = json.load(f)
                print(f"\t✅ Loaded class indices from {indices_load_path}")
            except Exception as e:
                print(
                    f"\t❌ Warning: Failed to load or parse class indices file: {e}")
                # Decide if you want to exit or proceed without labels
                # exit(1) # Exit if labels are critical
        else:
            print(
                f"\t❌ CRITICAL ERROR: Class indices file not found at {indices_load_path}. Cannot proceed with loading.")
            exit(1)  # Exit because indices are essential for interpreting model output

        try:
            # Pass loaded indices to the model constructor
            plant_classifier = PlantCNNModel(
                model_path=model_load_path,
                class_indices=loaded_indices  # Pass the loaded indices
            )
            # Verify loaded model matches expected classes (optional but recommended)
            if plant_classifier.model and plant_classifier.model.output_shape[-1] != len(loaded_indices):
                print(f"❌ CRITICAL ERROR: Loaded model output units ({plant_classifier.model.output_shape[-1]}) "
                      f"does not match number of classes in loaded indices ({len(loaded_indices)}).")
                exit(1)

            plant_classifier.get_summary()

            # --- Further Training ---
            train_further_choice = ""
            while train_further_choice not in ["yes", "y", "no", "n"]:
                train_further_choice = input(
                    "Train this loaded model further? (yes/no): ").strip().lower()

            if train_further_choice in ["yes", "y"]:
                # Need to regenerate datasets if resuming training
                print("\n--- Preparing Datasets for Further Training ---")
                # Regenerate datasets using the loaded_indices to ensure consistency
                # This assumes the *data source* hasn't changed fundamentally
                # Re-use the logic from the Dataset Preparation section, but force
                # using loaded_indices if possible.

                # Example for PlantClassifier (adjust paths/params as needed)
                if selected_model_type == "PlantClassifier":  # Need to know which type was loaded
                    print("Re-preparing PlantClassifier data...")
                    # Determine preprocessing based on loaded model? Or re-ask user?
                    # Assuming we use the same preprocessing as initially determined
                    # This part needs careful thought based on your workflow.
                    # For simplicity, let's re-run the dataset creation logic:
                    train_dir_pc = os.path.join(
                        BASE_DATA_DIR_PLANT_CLASSIFIER, TRAIN_SUBDIR_PLANT_CLASSIFIER)
                    val_dir_pc = os.path.join(
                        BASE_DATA_DIR_PLANT_CLASSIFIER, VAL_SUBDIR_PLANT_CLASSIFIER)
                    # Determine preprocessing_fn again or retrieve based on loaded model info if possible
                    # Let's assume scale_0_1 for simplicity here, adjust as needed
                    preprocessing_fn_resume = scale_0_1
                    print(
                        "Using simple 0-1 scaling for resumed training (adjust if needed).")

                    train_data, _, _, class_weight_dict = create_tf_dataset(
                        dir_path=train_dir_pc, batch_size=BATCH_SIZE,
                        preprocessing_fn=preprocessing_fn_resume, model="PlantClassifier",
                        # Use loaded names
                        is_training=True, class_names=list(loaded_indices.keys()),
                        return_labels_weights=True)
                    val_data, _, _, _ = create_tf_dataset(
                        dir_path=val_dir_pc, batch_size=BATCH_SIZE,
                        preprocessing_fn=preprocessing_fn_resume, model="PlantClassifier",
                        # Use loaded names
                        is_training=False, class_names=list(loaded_indices.keys()),
                        return_labels_weights=False)
                    print("Datasets re-prepared.")

                elif selected_model_type == "HealthDetector":  # Need to know which type was loaded
                    print("Re-preparing HealthDetector data...")
                    train_dir_hd = TRAIN_DIR_HEALTH_DETECTOR
                    val_dir_hd = VALID_DIR_HEALTH_DETECTOR
                    preprocessing_fn_resume = scale_0_1  # Assuming simple scaling
                    print("Using simple 0-1 scaling for resumed training.")

                    train_data, _, _, class_weight_dict = create_tf_dataset(
                        dir_path=train_dir_hd, batch_size=BATCH_SIZE,
                        preprocessing_fn=preprocessing_fn_resume, model="HealthDetector",
                        is_training=True, return_labels_weights=True)
                    val_data, _, _, _ = create_tf_dataset(
                        dir_path=val_dir_hd, batch_size=BATCH_SIZE,
                        preprocessing_fn=preprocessing_fn_resume, model="HealthDetector",
                        is_training=False, return_labels_weights=False)
                    print("Datasets re-prepared.")
                else:
                    print(
                        "❌ Cannot re-prepare dataset for unknown or unimplemented model type.")
                    exit(1)

                while True:
                    try:
                        epochs_input = input(
                            f"Enter number of additional epochs to train: ")
                        epochs_to_train = int(epochs_input)
                        if epochs_to_train > 0:
                            break
                        else:
                            print("❌ Please enter a positive number of epochs.")
                    except ValueError:
                        print("❌ Invalid input. Please enter an integer.")

                print('\n--- Resuming Training ---')
                plant_classifier.train(
                    train_generator=train_data,
                    validation_generator=val_data,
                    class_weight_dict=class_weight_dict,  # Need weights even when resuming
                    epochs=epochs_to_train,
                    base_log_dir=LOGS_DIR,
                    base_model_dir=MODELS_DIR,
                    model_name=selected_model_type,  # Pass model type for saving
                )

        except FileNotFoundError:
            # Already handled by select_model_checkpoint returning None
            pass  # Exit handled earlier
        except Exception as e:
            print(f"❌ Error loading model or during further training: {e}")
            # Print traceback for debugging
            import traceback
            traceback.print_exc()
            exit(1)

    # --- Deployment (Optional) ---
    print("\n--- Deployment ---")
    deploy_choice = ""
    while deploy_choice not in ["yes", "y", "no", "n"]:
        deploy_choice = input(
            "Deploy the final model (SavedModel format)? (yes/no): ").strip().lower()

    if deploy_choice in ["yes", "y"]:
        if plant_classifier is None or plant_classifier.model is None:
            print("❌ No model is available to deploy.")
        else:
            # Use a deployment directory perhaps related to the base model dir
            # Add model type to deployment path?
            # deployment_base = os.path.join(MODELS_DIR, f"deployment_{selected_model_type}")
            # plant_classifier.deploy(deploy_directory=deployment_base)
            plant_classifier.save_model(
                directory=save_dir,  # Use the model type directory
                filename=selected_model_type,  # Pass model type for saving

            )
    else:
        print("Skipping deployment.")

    print("\n--- Program Finished ---")


# --- Model Checkpoint Selection Function ---
def select_model_checkpoint(base_models_dir: str = "models") -> str | None:
    """
    Allows the user to select a trained model checkpoint from timestamped directories,
    handling both 'YYYYMMDD-HHMMSS' and 'ModelType_YYYYMMDD-HHMMSS' formats.

    Args:
        base_models_dir: The base directory containing timestamped model folders.

    Returns:
        The full path to the selected .keras model file, or None if cancelled/not found.
    """
    print(f"\n--- Selecting Model Checkpoint from '{base_models_dir}' ---")

    if not os.path.isdir(base_models_dir):
        print(f"❌ Error: Base models directory '{base_models_dir}' not found.")
        return None

    
    #    Regex breakdown: (these commets are for me too it is hard to remember)
    #    (?:[A-Za-z]+_)?  - Optional non-capturing group for 'ModelType_' prefix
    #       [A-Za-z]+    - One or more letters (model type)
    #       _            - Underscore
    #       ?            - Makes the prefix group optional
    #    \d{8}            - Exactly 8 digits (YYYYMMDD)
    #    -                - A hyphen
    #    \d{6}            - Exactly 6 digits (HHMMSS)
    #    $                - End of string    
    timestamp_pattern = re.compile(r"^(?:[A-Za-z]+_)?\d{8}-\d{6}$")   

    try:
        subdirs = [
            d for d in os.listdir(base_models_dir)
            if os.path.isdir(os.path.join(base_models_dir, d)) and timestamp_pattern.match(d)
        ]
    except OSError as e:
        print(f"❌ Error listing directories in '{base_models_dir}': {e}")
        return None

    if not subdirs:
        print("❌ No timestamped model directories (old or new format) found.")
        return None

    # Sort directories (might mix old and new formats, sorting ensures consistency)
    subdirs.sort(reverse=True)

   
    print("Available model training runs:")
    for i, dirname in enumerate(subdirs):
        # Shows the full name (old or new format)
        print(f"  {i + 1}: {dirname}")

    selected_dir_path = None
    while selected_dir_path is None:
        try:
            choice = input(
                f"Select a run number (1-{len(subdirs)}) or 'q' to quit: ").strip().lower()
            if choice == 'q':
                print("Selection cancelled.")
                return None
            index = int(choice) - 1
            if 0 <= index < len(subdirs):
                selected_dir_path = os.path.join(
                    base_models_dir, subdirs[index])
                print(f"Selected run: {subdirs[index]}")
            else:
                print("Invalid choice. Please enter a number from the list.")
        except ValueError:
            print("Invalid input. Please enter a number.")
        except KeyboardInterrupt:
            print("\nSelection cancelled.")
            return None

    available_models = []
    best_model_path = os.path.join(selected_dir_path, "best_model.keras")
    latest_model_path = os.path.join(
        selected_dir_path, "latest_checkpoint.keras")

    if os.path.exists(best_model_path):
        available_models.append(
            ("Best Model (best_model.keras)", best_model_path))
    if os.path.exists(latest_model_path):
        available_models.append(
            ("Latest Checkpoint (latest_checkpoint.keras)", latest_model_path))

    if not available_models:
        print(
            f"❌ Error: No 'best_model.keras' or 'latest_checkpoint.keras' found in {selected_dir_path}")
        return None


    print("\nAvailable checkpoints in this run:")
    for i, (desc, _) in enumerate(available_models):
        print(f"  {i + 1}: {desc}")

    selected_model_file_path = None
    while selected_model_file_path is None:
        try:
            choice = input(
                f"Select checkpoint number (1-{len(available_models)}) or 'q' to quit: ").strip().lower()
            if choice == 'q':
                print("Selection cancelled.")
                return None
            index = int(choice) - 1
            if 0 <= index < len(available_models):
                # Get the path
                selected_model_file_path = available_models[index][1]
                print(
                    f"Selected checkpoint file: {os.path.basename(selected_model_file_path)}")
            else:
                print("Invalid choice. Please enter a number from the list.")
        except ValueError:
            print("Invalid input. Please enter a number.")
        except KeyboardInterrupt:
            print("\nSelection cancelled.")
            return None


    return selected_model_file_path, selected_dir_path


if __name__ == "__main__":
    # Ensure necessary directories exist before starting (look at the top of the file)
    os.makedirs(MODELS_DIR, exist_ok=True)
    os.makedirs(LOGS_DIR, exist_ok=True)
    main()
