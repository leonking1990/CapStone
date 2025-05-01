import os
import tensorflow_datasets as tfds
import tensorflow as tf
import random
import shutil
import glob
from tqdm import tqdm # For progress bars


# this script prepares a dataset for a plant health detector by gathering images from existing datasets and Open Images v7.
# It creates a balanced dataset with plant and non-plant images, ensuring that the non-plant images do not contain any plant-related content.
# The dataset is split into training and validation sets, with a specified percentage for validation.
# The script also includes functions for checking directory existence, filtering images, saving images, and copying files with progress indication.


# --- Configuration ---

# Paths to existing plant datasets
PLANT_DATASET_PATHS = [
    "/research/PlantDataset/PlantCLEF2024/trainFiltered", # Plant Classifier data
    "/research/PlantDataset/PlantCLEF2024/valFiltered",   # Plant Classifier data
    "/research/New Plant Diseases Dataset(Augmented)/New Plant Diseases Dataset(Augmented)/train", # Health Detector data
    "/research/New Plant Diseases Dataset(Augmented)/New Plant Diseases Dataset(Augmented)/valid"  # Health Detector data
]

# Output directory for the prepared detector dataset
OUTPUT_BASE_DIR = "/research/PlantDataset/detector_dataset"

# Target number of images PER CLASS (plant, non_plant) in the final dataset
# Adjust this based on your needs and available disk space
TARGET_IMAGES_PER_CLASS = 20000

# Percentage of data to use for validation
VALIDATION_SPLIT = 0.15 # 15% for validation

# Open Images v7 configuration
TFDS_DATASET = 'open_images_v7'
# Using a larger slice for better chance of finding non-plant images
# Adjust slice size if needed (e.g., 'train[:10%]') - larger slices take longer to process
TFDS_SPLIT = 'train[:5%]'
NON_PLANT_LIMIT = TARGET_IMAGES_PER_CLASS # Target this many non-plant images

# Keywords to identify plant images in Open Images (used to EXCLUDE them for non-plant set)
# Be broader here to avoid accidentally including plants in the non-plant set
PLANT_KEYWORDS_FOR_EXCLUSION = ['Plant', 'Flower', 'Tree', 'Vegetation', 'Leaf', 'Fruit', 'Garden', 'Forest', 'Bush', 'Shrub', 'Grass']

# --- Helper Functions ---

def check_paths_exist(paths):
    """Checks if all provided directory paths exist."""
    all_exist = True
    for p in paths:
        if not os.path.isdir(p):
            print(f"❌ Error: Directory not found: {p}")
            all_exist = False
    return all_exist

def is_potentially_plant(example, info):
    """Checks if an Open Images example likely contains a plant based on object labels."""
    if 'objects' not in example or 'label' not in example['objects']:
        return False # No object labels to check

    try:
        # Decode labels using info.features (handle potential errors)
        label_indices = example['objects']['label']
        label_names = [info.features['objects']['label'].int2str(l) for l in label_indices]

        # Check if any label name contains any exclusion keyword
        for label_name in label_names:
            label_lower = label_name.lower()
            for keyword in PLANT_KEYWORDS_FOR_EXCLUSION:
                if keyword.lower() in label_lower:
                    return True # Found a plant-related keyword
        return False # No plant-related keywords found
    except Exception as e:
        # print(f"Warning: Error processing labels for an image: {e}") # Optional warning
        return False # Treat as non-plant if labels cause errors

def save_image_from_tensor(image_tensor, filepath):
    """Saves a TensorFlow image tensor to a JPEG file."""
    try:
        # Ensure the image is in the correct format (uint8)
        image_uint8 = tf.image.convert_image_dtype(image_tensor, tf.uint8)
        # Encode as JPEG
        encoded = tf.io.encode_jpeg(image_uint8, quality=90) # Adjust quality if needed
        # Write to file
        tf.io.write_file(filepath, encoded)
        return True
    except Exception as e:
        print(f"\nWarning: Failed to save image {os.path.basename(filepath)}. Error: {e}")
        return False

def gather_file_paths(dir_paths, extensions=('*.jpg', '*.jpeg', '*.png', '*.bmp')):
    """Recursively gathers all image file paths from a list of directories."""
    all_files = []
    print("Gathering plant image file paths...")
    for dir_path in dir_paths:
        print(f"  Scanning: {dir_path}")
        for ext in extensions:
            # Use recursive glob to find files in subdirectories
            pattern = os.path.join(dir_path, '**', ext)
            found_files = glob.glob(pattern, recursive=True)
            all_files.extend(found_files)
            print(f"    Found {len(found_files)} files with extension {ext}")
    print(f"Total plant image paths found: {len(all_files)}")
    return all_files

def create_output_dirs(base_dir, val_split):
    """Creates the train/validation directory structure."""
    train_plant_dir = os.path.join(base_dir, "train", "plant")
    train_nonplant_dir = os.path.join(base_dir, "train", "non_plant")
    val_plant_dir = os.path.join(base_dir, "validation", "plant")
    val_nonplant_dir = os.path.join(base_dir, "validation", "non_plant")

    os.makedirs(train_plant_dir, exist_ok=True)
    os.makedirs(train_nonplant_dir, exist_ok=True)
    if val_split > 0:
        os.makedirs(val_plant_dir, exist_ok=True)
        os.makedirs(val_nonplant_dir, exist_ok=True)

    return train_plant_dir, train_nonplant_dir, val_plant_dir, val_nonplant_dir


def copy_files_split(file_list, target_train_dir, target_val_dir, val_split, class_name):
    """Copies files to train/validation directories with progress."""
    random.shuffle(file_list) # Shuffle before splitting
    split_index = int(len(file_list) * (1 - val_split))
    train_files = file_list[:split_index]
    val_files = file_list[split_index:]

    print(f"\nCopying {class_name} files...")
    print(f"  Train ({len(train_files)} files) -> {target_train_dir}")
    copied_train = 0
    for src_path in tqdm(train_files, desc=f"Train {class_name}", unit="file"):
        try:
            filename = os.path.basename(src_path)
            dst_path = os.path.join(target_train_dir, filename)
            # Avoid overwriting if somehow filenames clash (unlikely with sampling)
            if not os.path.exists(dst_path):
                 shutil.copy2(src_path, dst_path) # copy2 preserves metadata
                 copied_train += 1
        except Exception as e:
            print(f"\nWarning: Failed to copy {src_path}. Error: {e}")

    copied_val = 0
    if val_split > 0 and target_val_dir:
        print(f"  Validation ({len(val_files)} files) -> {target_val_dir}")
        for src_path in tqdm(val_files, desc=f"Val {class_name}", unit="file"):
             try:
                 filename = os.path.basename(src_path)
                 dst_path = os.path.join(target_val_dir, filename)
                 if not os.path.exists(dst_path):
                     shutil.copy2(src_path, dst_path)
                     copied_val += 1
             except Exception as e:
                 print(f"\nWarning: Failed to copy {src_path}. Error: {e}")

    print(f"  Successfully copied {copied_train} train and {copied_val} validation {class_name} files.")
    return copied_train, copied_val


# --- Main Execution ---
if __name__ == "__main__":
    print("--- Starting Plant Detector Dataset Preparation ---")

    # 1. Check if source plant directories exist
    if not check_paths_exist(PLANT_DATASET_PATHS):
        print("\nPlease ensure all source plant dataset paths are correct.")
        exit(1)

    # 2. Create output directories
    train_plant_dir, train_nonplant_dir, val_plant_dir, val_nonplant_dir = create_output_dirs(OUTPUT_BASE_DIR, VALIDATION_SPLIT)
    print(f"Output directories created/ensured under: {OUTPUT_BASE_DIR}")

    # 3. Prepare Non-Plant Images from Open Images v7
    print(f"\n--- Preparing Non-Plant Images (Target: {NON_PLANT_LIMIT}) ---")
    print(f"Loading TFDS dataset: {TFDS_DATASET}, Split: {TFDS_SPLIT}")
    try:
        # Load dataset info first
        builder = tfds.builder(TFDS_DATASET)
        info = builder.info
        # Download and prepare if necessary (this might take time on first run)
        builder.download_and_prepare()
        # Load the specified split
        ds = builder.as_dataset(split=TFDS_SPLIT, shuffle_files=True) # Shuffle files for better randomness
        print("Dataset loaded.")

        # Filter for non-plant images
        # Use a lambda that captures the 'info' variable correctly
        nonplant_filter = lambda ex: tf.logical_not(is_potentially_plant(ex, info))
        nonplant_ds = ds.filter(nonplant_filter)

        # Iterate and save non-plant images
        nonplant_saved_files = []
        saved_count = 0
        # Use tqdm for progress bar
        with tqdm(total=NON_PLANT_LIMIT, desc="Saving non-plant", unit="img") as pbar:
            for example in nonplant_ds:
                if saved_count >= NON_PLANT_LIMIT:
                    break
                # Create a unique filename (e.g., using image ID if available)
                img_id = example.get('image/id', tf.timestamp()).numpy() # Use timestamp as fallback ID
                filename = f"nonplant_{img_id}.jpg"
                filepath = os.path.join(OUTPUT_BASE_DIR, filename) # Save temporarily

                if save_image_from_tensor(example['image'], filepath):
                    nonplant_saved_files.append(filepath)
                    saved_count += 1
                    pbar.update(1)

        print(f"\nFinished saving {saved_count} non-plant images temporarily.")

        # Copy temporary non-plant files to final train/val directories
        if nonplant_saved_files:
             _, _ = copy_files_split(nonplant_saved_files, train_nonplant_dir, val_nonplant_dir, VALIDATION_SPLIT, "non-plant")
             # Clean up temporary files
             print("Cleaning up temporary non-plant files...")
             for f in nonplant_saved_files:
                 try:
                     os.remove(f)
                 except OSError as e:
                     print(f"Warning: Could not remove temp file {f}: {e}")
        else:
             print("No non-plant images were saved.")


    except Exception as e:
        print(f"\n❌ Error during Open Images processing: {e}")
        print("Please ensure 'tensorflow-datasets' is installed and you have internet access.")
        # Consider exiting or continuing without non-plant images
        # exit(1)


    # 4. Prepare Plant Images
    print(f"\n--- Preparing Plant Images (Target: {TARGET_IMAGES_PER_CLASS}) ---")
    all_plant_files = gather_file_paths(PLANT_DATASET_PATHS)

    if not all_plant_files:
        print("❌ Error: No plant image files found in the specified directories.")
        exit(1)

    # Randomly sample the target number of plant images
    if len(all_plant_files) < TARGET_IMAGES_PER_CLASS:
        print(f"Warning: Found only {len(all_plant_files)} plant images, which is less than the target {TARGET_IMAGES_PER_CLASS}. Using all found images.")
        selected_plant_files = all_plant_files
    else:
        print(f"Sampling {TARGET_IMAGES_PER_CLASS} plant images from {len(all_plant_files)} found files...")
        selected_plant_files = random.sample(all_plant_files, TARGET_IMAGES_PER_CLASS)
        print("Sampling complete.")

    # Copy selected plant files to final train/val directories
    if selected_plant_files:
        _, _ = copy_files_split(selected_plant_files, train_plant_dir, val_plant_dir, VALIDATION_SPLIT, "plant")
    else:
        print("No plant images were selected or copied.")


    print("\n--- Plant Detector Dataset Preparation Complete ---")
    print(f"Dataset created in: {OUTPUT_BASE_DIR}")
    print(f"Check subdirectories: {os.path.join(OUTPUT_BASE_DIR, 'train')}, {os.path.join(OUTPUT_BASE_DIR, 'validation')}")

