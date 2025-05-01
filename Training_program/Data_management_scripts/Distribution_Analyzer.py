import os
import matplotlib.pyplot as plt
import pandas as pd

# ✅ Set your dataset directory path
DATASET_DIR = '/research/PlantDataset/PlantCLEF2024/trainFiltered'  # e.g., '/home/user/dataset'

# 🧮 Count images per class
class_counts = {}
for class_name in os.listdir(DATASET_DIR):
    class_dir = os.path.join(DATASET_DIR, class_name)
    if os.path.isdir(class_dir):
        count = len([
            f for f in os.listdir(class_dir)
            if os.path.isfile(os.path.join(class_dir, f))
        ])
        class_counts[class_name] = count

# 🔢 Convert to DataFrame
df = pd.DataFrame(list(class_counts.items()), columns=['class', 'image_count'])
df_sorted = df.sort_values(by='image_count', ascending=False)

# 📈 Plot histogram
plt.figure(figsize=(15, 6))
plt.hist(df["image_count"], bins=100, color='skyblue', edgecolor='black')
plt.title("Distribution of Images per Class")
plt.xlabel("Number of Images")
plt.ylabel("Number of Classes")
plt.grid(True)
plt.tight_layout()
plt.show()

# 💾 Save CSV
df_sorted.to_csv("class_distribution_trainFiltered.csv", index=False)

# 🔍 Print top and bottom 10
print("\nTop 10 classes by image count:\n", df_sorted.head(10))
print("\nBottom 10 classes by image count:\n", df_sorted.tail(10))

