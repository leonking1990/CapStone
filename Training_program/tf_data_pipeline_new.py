import tensorflow as tf
import os
import json
import numpy as np
from sklearn.utils import class_weight
# Need io and contextlib for the health detector's stdout capture
import io
from contextlib import redirect_stdout
from typing import Optional, Tuple, List, Dict, Any

AUTOTUNE = tf.data.AUTOTUNE

# --- Configuration ---
IMG_HEIGHT = 224
IMG_WIDTH = 224
IMG_CHANNELS = 3
IMG_SIZE = (IMG_HEIGHT, IMG_WIDTH) # Define IMG_SIZE used by health detector

# --- Shared Helper Functions ---

def decode_and_pad_image(image_bytes, preprocessing_fn=None):
    """Decodes image bytes, pads to square, resizes, and applies preprocessing."""
    # Decode image
    img = tf.io.decode_image(
        image_bytes, channels=IMG_CHANNELS, expand_animations=False)
    img.set_shape([None, None, IMG_CHANNELS]) # Explicitly set shape

    # Pad to square
    shape = tf.shape(img)
    h, w = shape[0], shape[1]
    size = tf.maximum(h, w)
    pad_h = size - h
    pad_w = size - w
    pad_top = pad_h // 2
    pad_bottom = pad_h - pad_top
    pad_left = pad_w // 2
    pad_right = pad_w - pad_left
    paddings = [[pad_top, pad_bottom], [pad_left, pad_right], [0, 0]]
    img = tf.pad(img, paddings, mode='CONSTANT', constant_values=0)

    # Resize
    img = tf.image.resize(img, [IMG_HEIGHT, IMG_WIDTH], method=tf.image.ResizeMethod.BILINEAR)
    img = tf.ensure_shape(img, [IMG_HEIGHT, IMG_WIDTH, IMG_CHANNELS])

    # Cast and preprocess
    img = tf.cast(img, tf.float32)
    if preprocessing_fn:
        img = preprocessing_fn(img)
    else:
        img = img / 255.0 # Default scaling

    return img

def process_path(file_path, label, preprocessing_fn=None):
    """Loads image bytes from path and applies preprocessing."""
    img_bytes = tf.io.read_file(file_path)
    # Pass preprocessing_fn down to decode_and_pad_image
    img = decode_and_pad_image(img_bytes, preprocessing_fn=preprocessing_fn)
    return img, label

# --- Augmentation Pipeline (Used by prepare_dataset if augment=True) ---
# Image augmentation for training data
# augmentation is used to increase the diversity of the training dataset
# by applying random transformations to the images
# uncomment the lines below to apply augmentation 
data_augmentation_pipeline = tf.keras.Sequential([
    # aujest values for your needs
    tf.keras.layers.RandomFlip("horizontal"),       # Horizontal flip is often useful for plants
    # tf.keras.layers.RandomFlip("vertical"),       # Vertical flip can be useful for some datasets
    tf.keras.layers.RandomContrast(factor=0.1),     # Adjust contrast
    tf.keras.layers.RandomRotation(factor=0.1),     # Rotate images by 10%
    tf.keras.layers.RandomZoom(height_factor=0.1, width_factor=0.1),            # Zoom in/out by 10%
    tf.keras.layers.RandomTranslation(height_factor=0.05, width_factor=0.05),   # Translate images by 5%
    tf.keras.layers.RandomBrightness(factor=0.2),   # Adjust brightness
    tf.keras.layers.RandomContrast(factor=0.2),     # Adjust contrast
    # tf.keras.layers.RandomSaturation(factor=0.1), # Adjust saturation (if applicable)
    # tf.keras.layers.RandomHue(factor=0.05),       # Adjust hue (if applicable)
], name="data_augmentation")

def augment_image(image, label):
    """Applies data augmentation."""
    image = data_augmentation_pipeline(image, training=True)
    # Optional: Clip values if augmentations might push them outside expected range
    # image = tf.clip_by_value(image, 0.0, 1.0) # If preprocessing scales to [0,1]
    return image, label

def prepare_dataset(ds: tf.data.Dataset, batch_size: int, shuffle: bool, augment: bool):
    """Applies caching, shuffling, augmentation, batching, and prefetching."""
    # Cache before augmentation/batching (optional, monitor memory)
    # ds = ds.cache()

    if shuffle:
        # Use a fixed buffer size or estimate based on dataset size if possible
        shuffle_buffer = 10000 # Adjust as needed
        print(f"\t\tShuffling dataset with buffer size: {shuffle_buffer}")
        ds = ds.shuffle(shuffle_buffer, reshuffle_each_iteration=True)

    # Apply augmentation if specified
    if augment:
        print("\t\tApplying data augmentation.")
        ds = ds.map(augment_image, num_parallel_calls=AUTOTUNE)

    # Batch the dataset
    ds = ds.batch(batch_size)

    # Prefetch for performance
    ds = ds.prefetch(buffer_size=AUTOTUNE)
    return ds

# --- Health Detector Specific Functions ---

def map_to_health_label(image, label_index, health_label_table):
    """Maps inferred integer label to binary health label (0=healthy, 1=unhealthy)."""
    label_index_64 = tf.cast(label_index, dtype=tf.int64)
    class_name_tensor = health_label_table.lookup(label_index_64)
    # Check if the directory name contains 'healthy' (case-insensitive)
    is_healthy = tf.strings.regex_full_match(class_name_tensor, ".*[Hh]ealthy.*")
    health_label = tf.where(is_healthy,
                            tf.constant(0, dtype=tf.int64), # 0 for healthy
                            tf.constant(1, dtype=tf.int64)) # 1 for unhealthy
    return image, tf.cast(health_label, tf.int32)

def compute_binary_class_weights(labels_list: List[int]) -> Dict[int, float]:
    """Computes class weights for binary classification."""
    y_train = np.array(labels_list)
    try:
        class_weights = class_weight.compute_class_weight(
            class_weight='balanced',
            classes=np.unique(y_train),
            y=y_train
        )
        # Ensure weights exist for both classes 0 and 1, even if one is missing
        weight_dict = {0: 1.0, 1: 1.0} # Default weights
        unique_classes = np.unique(y_train)
        for i, cls in enumerate(unique_classes):
             if cls in [0, 1]: # Only consider 0 and 1
                 weight_dict[cls] = class_weights[i]

        # Handle case where only one class is present in the batch/data used
        if 0 not in unique_classes:
            print("Warning: Class 0 (healthy) not found for weight calculation. Using default weight 1.0.")
        if 1 not in unique_classes:
            print("Warning: Class 1 (unhealthy) not found for weight calculation. Using default weight 1.0.")

        return weight_dict

    except ValueError as e:
         print(f"Warning: Could not compute class weights ({e}). Using default weights.")
         return {0: 1.0, 1: 1.0} # Return default weights if calculation fails


# --- Plant Classifier Specific Functions ---

def compute_multiclass_class_weights(dir_path: str, class_indices: Dict[str, int]) -> Dict[int, float]:
    """Computes class weights by scanning all folders that end with the target class name."""
    labels_list = []
    print("\t\tCalculating multi-class weights by scanning folders...")

    all_folders = [
        f for f in os.listdir(dir_path)
        if os.path.isdir(os.path.join(dir_path, f))
    ]

    for class_name, index in class_indices.items():
        # Match folders where the disease part (after ___) is class_name
        matching_folders = [
            f for f in all_folders if f.endswith(f"___{class_name}")
        ]

        count = 0
        for folder in matching_folders:
            class_dir = os.path.join(dir_path, folder)
            try:
                count += len([
                    f for f in os.listdir(class_dir)
                    if os.path.isfile(os.path.join(class_dir, f))
                ])
            except Exception as e:
                print(f"\t\tWarning: Error scanning {folder}: {e}")
        
        labels_list.extend([index] * count)

    if not labels_list:
        print("\t\tWarning: No labels found. Using default weights.")
        return {i: 1.0 for i in range(len(class_indices))}

    y_train = np.array(labels_list)
    unique_classes = np.unique(y_train)

    try:
        computed_weights = class_weight.compute_class_weight(
            class_weight='balanced',
            classes=unique_classes,
            y=y_train
        )
        class_weight_dict = {cls: weight for cls, weight in zip(unique_classes, computed_weights)}
        final_weight_dict = {i: class_weight_dict.get(i, 1.0) for i in range(len(class_indices))}
        print("\t\tMulti-class weights calculated.")
        return final_weight_dict
    except ValueError as e:
        print(f"\t\tWarning: Could not compute weights ({e}). Using defaults.")
        return {i: 1.0 for i in range(len(class_indices))}



# --- Main Dataset Creation Function ---

def create_tf_dataset(
    dir_path: str,
    batch_size: int,
    preprocessing_fn: Optional[callable], # Made optional for health detector?
    model: str, # Added model type parameter
    is_training: bool = False,
    class_names: Optional[List[str]] = None, # Used by PlantClassifier
    return_labels_weights: bool = False,
    # Added parameters for health detector compatibility
    subset: Optional[str] = None,
    validation_split: float = 0.2
    ) -> Tuple[tf.data.Dataset, List[str], Dict[str, int], Optional[Dict[int, float]]]:
    """
    Creates an optimized tf.data.Dataset based on the specified model type.

    Args:
        dir_path (str): Path to the dataset directory.
        batch_size (int): The batch size.
        preprocessing_fn (callable, optional): Function for image preprocessing.
        model (str): The type of model ("PlantClassifier", "HealthDetector").
        is_training (bool): If True, applies shuffling and augmentation.
        class_names (list, optional): Predefined class names (PlantClassifier).
        return_labels_weights (bool): If True, calculates and returns class weights.
        subset (str, optional): 'training', 'validation', or None (HealthDetector).
        validation_split (float): Fraction for validation split (HealthDetector).

    Returns:
        Tuple containing:
            tf.data.Dataset: The configured dataset.
            list: The list of class names used.
            dict: The class indices mapping {name: index}.
            dict, optional: Dictionary mapping class indices to weights, or None.
    """
    print(f"\n--- Creating Dataset for Model Type: {model} ---")
    print(f"Directory: {dir_path}")

    ds = None
    final_class_names = []
    final_class_indices = {}
    class_weight_dict = None

    # ==================================
    # === PlantClassifier Logic Branch ===
    # ==================================
    if model == "PlantClassifier":
        print("Using PlantClassifier data loading strategy (list_files)...")

        label_type = "species" # Default label type for PlantClassifier
        
        if preprocessing_fn is None:
            print("Warning: preprocessing_fn is recommended for PlantClassifier.")

        # === Set label_type: "species" or "condition"
        assert label_type in ["species", "condition"], "label_type must be 'species' or 'condition'"

        # List files and count them
        try:
            list_files_pattern = os.path.join(dir_path, '*', '*')
            ds_files = tf.data.Dataset.list_files(list_files_pattern, shuffle=False)
            image_count = ds_files.cardinality().numpy() if ds_files.cardinality() != tf.data.INFINITE_CARDINALITY else -1
            if image_count == 0:
                raise ValueError(f"No image files found matching pattern: {list_files_pattern}")
            print(f"\t\tFound {image_count} image files.")
        except Exception as e:
            raise ValueError(f"Error listing files in {dir_path}: {e}")

        # === Extract all folder names to infer labels
        try:
            folder_names = [
                f for f in tf.io.gfile.listdir(dir_path)
                if tf.io.gfile.isdir(os.path.join(dir_path, f))
            ]

            # Use only the part you need (either species or condition)
            if label_type == "species":
                class_names = sorted(set(f.split("___")[0] for f in folder_names))
            else:
                class_names = sorted(set(f.split("___")[1] if "___" in f else "unknown" for f in folder_names))

            if not class_names:
                raise ValueError(f"No {label_type} class names found in folder names.")

            print(f"\t\tInferred {len(class_names)} '{label_type}' classes: {class_names}")
        except Exception as e:
            raise ValueError(f"Error inferring class names from {dir_path}: {e}")

        final_class_names = class_names
        num_classes = len(final_class_names)
        final_class_indices = {name: i for i, name in enumerate(final_class_names)}

        # === Label extraction function
        def get_label(file_path):
            parts = tf.strings.split(file_path, os.path.sep)
            folder_name = parts[-2]

            def extract_label(name):
                decoded = name.numpy().decode()
                if "___" in decoded:
                    if label_type == "species":
                        label_part = decoded.split("___")[0]
                    else:
                        label_part = decoded.split("___")[1]
                else:
                    label_part = "unknown"
                return final_class_indices.get(label_part, -1)

            label_index = tf.py_function(extract_label, [folder_name], tf.int64)
            label_index.set_shape([])
            return tf.cast(label_index, tf.int32)

        # === Create (image_path, label) dataset
        labels_ds = ds_files.map(get_label, num_parallel_calls=AUTOTUNE)
        ds = tf.data.Dataset.zip((ds_files, labels_ds))
        ds = ds.filter(lambda x, y: y != -1)

        # Optional: class weights for imbalanced data
        # this helps to balance the dataset by assigning higher weights to underrepresented classes
        # and lower weights to overrepresented classes
        if return_labels_weights and is_training:
            class_weight_dict = compute_multiclass_class_weights(dir_path, final_class_indices)

        # === Load and preprocess images
        map_fn = lambda file_path, label: process_path(file_path, label, preprocessing_fn=preprocessing_fn)
        ds = ds.map(map_fn, num_parallel_calls=AUTOTUNE)

        # === Final prep
        ds = prepare_dataset(ds, batch_size=batch_size, shuffle=is_training, augment=is_training)
        
    
    elif model == "HealthClassifier":
        print("Using HealthClassifier data loading strategy (condition-only labels)...")

        if preprocessing_fn is None:
            print("Warning: preprocessing_fn is recommended for HealthClassifier.")

        # List files from all species-condition folders
        try:
            list_files_pattern = os.path.join(dir_path, '*', '*')
            ds_files = tf.data.Dataset.list_files(list_files_pattern, shuffle=False)
            image_count = ds_files.cardinality().numpy() if ds_files.cardinality() != tf.data.INFINITE_CARDINALITY else -1
            if image_count == 0:
                raise ValueError(f"No image files found matching pattern: {list_files_pattern}")
            print(f"\t\tFound {image_count} image files.")
        except Exception as e:
            raise ValueError(f"Error listing files in {dir_path}: {e}")

        # Infer condition labels from folder names
        try:
            folder_names = [
                f for f in tf.io.gfile.listdir(dir_path)
                if tf.io.gfile.isdir(os.path.join(dir_path, f))
            ]
            condition_names = sorted(set(
                f.split("___")[1] if "___" in f else "unknown" for f in folder_names
            ))

            if not condition_names:
                raise ValueError("No condition labels could be inferred from folder names.")
            print(f"\t\tInferred {len(condition_names)} conditions: {condition_names}")
        except Exception as e:
            raise ValueError(f"Error inferring condition labels from {dir_path}: {e}")

        final_condition_names = condition_names
        num_conditions = len(final_condition_names)
        condition_indices = {name: i for i, name in enumerate(final_condition_names)}

        # Define label extraction for conditions
        def get_condition_label(file_path):
            parts = tf.strings.split(file_path, os.path.sep)
            folder_name = parts[-2]

            def extract_condition(name):
                decoded = name.numpy().decode()
                condition = decoded.split("___")[1] if "___" in decoded else "unknown"
                return condition_indices.get(condition, -1)

            label_index = tf.py_function(extract_condition, [folder_name], tf.int64)
            label_index.set_shape([])
            return tf.cast(label_index, tf.int32)

        # Create labels dataset
        labels_ds = ds_files.map(get_condition_label, num_parallel_calls=AUTOTUNE)
        ds = tf.data.Dataset.zip((ds_files, labels_ds))
        ds = ds.filter(lambda x, y: y != -1)

        # Optional: class weights
        # this helps to balance the dataset by assigning higher weights to underrepresented classes
        # and lower weights to overrepresented classes
        if return_labels_weights and is_training:
            class_weight_dict = compute_multiclass_class_weights(dir_path, condition_indices)

        # Load and preprocess
        map_fn = lambda file_path, label: process_path(file_path, label, preprocessing_fn=preprocessing_fn)
        ds = ds.map(map_fn, num_parallel_calls=AUTOTUNE)

        # Prepare for training/inference
        ds = prepare_dataset(ds, batch_size=batch_size, shuffle=is_training, augment=is_training)
        
        # Assign the calculated condition_indices to the variable that will be returned
        final_class_indices = condition_indices
        final_class_names = final_condition_names # Also ensure class names are assigned for return
        
        
    # =================================
    # === HealthDetector Logic Branch ===
    # =================================
    elif model == "HealthDetector":
        print("Using HealthDetector data loading strategy (image_dataset_from_directory)...")
        final_class_names = ['healthy', 'unhealthy'] # Define explicit binary classes
        final_class_indices = {'healthy': 0, 'unhealthy': 1}

        # Load dataset using image_dataset_from_directory
        # Capture stdout to show the findings
        f = io.StringIO()
        with redirect_stdout(f):
             try:
                 if subset in ['training', 'validation']:
                     ds_initial = tf.keras.utils.image_dataset_from_directory(
                         dir_path,
                         labels='inferred',
                         label_mode='int', # Load integer labels for all original classes
                         image_size=IMG_SIZE,
                         interpolation='nearest',
                         batch_size=batch_size, # Load unbatched initially for label processing
                         shuffle=False, # Shuffle later in prepare_dataset
                         seed=123,
                         validation_split=validation_split,
                         subset=subset,
                     )
                 elif subset is None: # Load entire directory (e.g., for dedicated valid/test set)
                     ds_initial = tf.keras.utils.image_dataset_from_directory(
                         dir_path,
                         labels='inferred',
                         label_mode='int',
                         image_size=IMG_SIZE,
                         interpolation='nearest',
                         batch_size=batch_size, # Load unbatched initially
                         shuffle=False,
                     )
                 else:
                      raise ValueError(f"Invalid subset value: {subset}. Use 'training', 'validation', or None.")

             except Exception as e:
                  raise ValueError(f"Error loading dataset using image_dataset_from_directory from {dir_path}: {e}")

        # Print the captured output nicely
        captured_output = f.getvalue()
        for line in captured_output.strip().split('\n'):
            if line.strip().startswith("Found"):
                print(f"\t\t{line.strip()}")
            else:
                print(line.strip())

        # Get inferred class names for mapping table
        inferred_class_names = ds_initial.class_names
        print(f"\t\tFound {len(inferred_class_names)} original subdirectories for health mapping.")

        # Create lookup table: inferred int index -> inferred class name string
        health_label_table = tf.lookup.StaticHashTable(
            initializer=tf.lookup.KeyValueTensorInitializer(
                keys=tf.constant(list(range(len(inferred_class_names))), dtype=tf.int64),
                values=tf.constant(inferred_class_names, dtype=tf.string)
            ),
            default_value=tf.constant('', dtype=tf.string)
        )

        # Apply mapping function: inferred label -> binary health label (0/1)
        # Need to unbatch first to apply mapping element-wise, then re-batch later
        ds_unbatched = ds_initial.unbatch()
        map_fn_health = lambda image, label: map_to_health_label(image, label, health_label_table)
        ds_mapped = ds_unbatched.map(map_fn_health, num_parallel_calls=AUTOTUNE)

        # Apply preprocessing function (if provided) AFTER health mapping
        # The image_dataset_from_directory already loads images, we just need scaling/model-specific prep
        def apply_preprocessing(image, label):
             # Cast image back to float32 if needed, as image_dataset loads uint8
             image = tf.cast(image, tf.float32)
             if preprocessing_fn:
                 image = preprocessing_fn(image)
             else:
                 image = image / 255.0 # Default scaling
             return image, label

        ds = ds_mapped.map(apply_preprocessing, num_parallel_calls=AUTOTUNE)


        # Calculate class weights if requested
        if return_labels_weights and is_training:
             print("\t\tCalculating binary class weights...")
             # Need to iterate through the dataset to get all labels
             # This can be slow for large datasets! Consider pre-calculating if possible.
             try:
                  all_labels = [label.numpy() for _, label in ds] # Collect all labels
                  class_weight_dict = compute_binary_class_weights(all_labels)
                  print(f"\t\tBinary weights calculated: {class_weight_dict}")
             except Exception as e:
                  print(f"\t\tWarning: Could not extract all labels for weight calculation: {e}. Using default weights.")
                  class_weight_dict = {0: 1.0, 1: 1.0}


        # Apply common preparation steps (shuffling, augmentation, batching, prefetching)
        # Setting augment=False based on original call, but could be is_training
        ds = prepare_dataset(ds, batch_size=batch_size, shuffle=is_training, augment=False) # Set augment=False for now


    # =========================
    # === Unknown Model Type ===
    # =========================
    else:
        raise ValueError(f"Unknown model type '{model}'. Expected 'PlantClassifier' or 'HealthDetector'.")


    print(f"--- Dataset creation complete for model: {model} ---")
    return ds, final_class_names, final_class_indices, class_weight_dict
