import os
import pandas as pd
import shutil
from concurrent.futures import ThreadPoolExecutor, as_completed
from collections import defaultdict

# Configuration
SAMPLE_SIZE_PER_CLASS = 10  # Fixed number of images per class
NUM_WORKERS = 4  # Reduce workers to avoid disk contention

# Load the CSV file
csv_file = "/research/PlantDataset/PlantCLEF2024singleplanttrainingdata.csv"
data = pd.read_csv(csv_file, delimiter=";", dtype={'partner': str}, low_memory=False)

# Define source folders where images are located
source_folders = {
    "train": "/research/PlantDataset/PlantCLEF2024/train",
    "val": "/research/PlantDataset/PlantCLEF2024/val",
    "test": "/research/PlantDataset/PlantCLEF2024/test"
}

# Destination
destination_folder = "/research/PlantDataset/small_dataset"

# Load valid species IDs
class_mapping_file = "/research/PlantDataset/PlantCLEF2024/class_mapping.txt"
valid_species_ids = set()
if os.path.exists(class_mapping_file):
    with open(class_mapping_file, "r") as f:
        valid_species_ids = {line.strip() for line in f}

# Step 1: Preload image file paths into a dictionary (Avoid slow `glob`)
image_paths = defaultdict(dict)
for dataset_type, folder in source_folders.items():
    for root, _, files in os.walk(folder):  # Walk through all files
        for file in files:
            image_paths[dataset_type][file] = os.path.join(root, file)

# Step 2: Sample data for smaller dataset
sampled_data = []
for dataset_type in source_folders.keys():
    subset = data[data['learn_tag'] == dataset_type]  # Filter by dataset
    sampled_rows = subset.groupby('species_id', group_keys=False).apply(
        lambda x: x.sample(min(len(x), SAMPLE_SIZE_PER_CLASS))  # Ensure max 10 per class
    )
    sampled_data.append(sampled_rows)

sampled_data = pd.concat(sampled_data)

# Function to copy image files in parallel
def copy_image(row):
    image_name = row['image_name']
    species_id = str(row['species_id'])
    dataset_type = row['learn_tag']

    if dataset_type not in source_folders or species_id not in valid_species_ids:
        return f"Skipping {image_name} (Invalid dataset type or species ID)"

    # Preloaded path lookup
    src_path = image_paths[dataset_type].get(image_name)
    if not src_path:
        return f"File not found: {image_name}"

    # Destination folder
    dst_folder = os.path.join(destination_folder, dataset_type, species_id)
    os.makedirs(dst_folder, exist_ok=True)

    # Copy using efficient method
    dst_path = os.path.join(dst_folder, image_name)
    shutil.copyfile(src_path, dst_path)  # Fastest way to copy files

    return f"Copied: {image_name}"

# Step 3: Parallel Execution
num_images = 0
with ThreadPoolExecutor(max_workers=NUM_WORKERS) as executor:
    future_to_image = {executor.submit(copy_image, row): row for _, row in sampled_data.iterrows()}

    for future in as_completed(future_to_image):
        result = future.result()
        num_images += 1
        if num_images % 500 == 0:  # Reduce print frequency
            print(f"Processed {num_images} images")

print("Small dataset creation complete!")
