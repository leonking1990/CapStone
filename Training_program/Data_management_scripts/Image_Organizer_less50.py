import pandas as pd

# Load the new class distribution
df = pd.read_csv("class_distribution_new.csv")

# Keep only classes with 50+ images
filtered_df = df[df["image_count"] >= 50]

# Save filtered list
filtered_df.to_csv("class_distribution_filtered.csv", index=False)

print(f"Remaining classes: {len(filtered_df)} out of {len(df)}")
