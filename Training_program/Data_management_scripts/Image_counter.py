import os

DATASET_DIR = "/research/PlantDataset/PlantCLEF2024/trainFiltered"
total_images = 0

for root, dirs, files in os.walk(DATASET_DIR):
    image_files = [f for f in files if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
    total_images += len(image_files)

print(f"📸 Total images in trainFiltered: {total_images}")
