import os
import pandas as pd
import shutil
from glob import glob

# Load the CSV file
csv_file = "/research/PlantDataset/PlantCLEF2024singleplanttrainingdata.csv"
data = pd.read_csv(csv_file, delimiter=";", dtype={'partner': str}, low_memory=False)

# Define source folders where images are located
source_folders = {
    "train": "/research/PlantDataset/PlantCLEF2024/train",
    "val": "/research/PlantDataset/PlantCLEF2024/val",
    "test": "/research/PlantDataset/PlantCLEF2024/test"
}

# Path to the destination folder
destination_folder = "/research/PlantDataset/organized_images"

# Load valid species IDs from class_mapping.txt
class_mapping_file = "/research/PlantDataset/PlantCLEF2024/class_mapping.txt"
valid_species_ids = set()

if os.path.exists(class_mapping_file):
    with open(class_mapping_file, "r") as f:
        valid_species_ids = {line.strip() for line in f}

# Function to find image path in subdirectories
def find_image(image_name, dataset_type):
    folder = source_folders[dataset_type]
    match = glob(os.path.join(folder, "**", image_name), recursive=True)
    return match[0] if match else None  # Return first match if found, else None

# Move or copy files into their respective class folders while keeping dataset separation
numImages = 0
for index, row in data.iterrows():
    image_name = row['image_name']
    species_id = str(row['species_id'])
    dataset_type = row['learn_tag']  # Ensure this column contains train/val/test labels

    if dataset_type not in source_folders:
        print(f"Skipping {image_name} (Unknown dataset type: {dataset_type})")
        continue

    # Ensure species ID is valid
    if species_id not in valid_species_ids:
        print(f"Skipping {image_name} (Species ID not in class_mapping.txt: {species_id})")
        continue

    # Create destination folder using species_id
    dst_folder = os.path.join(destination_folder, dataset_type, species_id)
    os.makedirs(dst_folder, exist_ok=True)

    # Find and copy/move image
    src_path = find_image(image_name, dataset_type)
    if src_path:
        numImages += 1
        dst_path = os.path.join(dst_folder, image_name)
        shutil.copy(src_path, dst_path)  # Use shutil.move() if you want to move instead
    else:
        print(f"File not found: {image_name} in {dataset_type}")
    if numImages % 100 == 0:
        print(f"Current number of images: {numImages}")

print("Data organization complete while preserving train, val, and test sets!")
