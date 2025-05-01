import os
import shutil
import pandas as pd

# Paths
SOURCE_DIR = "/research/PlantDataset/PlantCLEF2024/val"
DEST_DIR = "/research/PlantDataset/PlantCLEF2024/valFiltered"
os.makedirs(DEST_DIR, exist_ok=True)

# Load valid class IDs
filtered_df = pd.read_csv("/research/PlantDataset/PlantCLEF2024/class_distribution_filtered.csv")
valid_classes = filtered_df["class"].astype(str).tolist()

# Move entire folders
for class_id in valid_classes:
    src = os.path.join(SOURCE_DIR, class_id)
    dest = os.path.join(DEST_DIR, class_id)

    if os.path.exists(src) and os.path.isdir(src):
        shutil.move(src, dest)
        print(f"✅ Moved class {class_id}")
    else:
        print(f"⚠️ Folder not found: {class_id}")
