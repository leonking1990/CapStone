import os

# Paths
train_path = "/research/PlantDataset/PlantCLEF2024/trainFiltered"
val_path = "/research/PlantDataset/PlantCLEF2024/valFiltered"

# Get class folders
train_classes = set(os.listdir(train_path))
val_classes = set(os.listdir(val_path))

# Compare
only_in_train = train_classes - val_classes
only_in_val = val_classes - train_classes
common_classes = train_classes & val_classes

# Print results
print(f"✅ Matching classes: {len(common_classes)}")
print(f"❌ Classes only in trainFiltered: {len(only_in_train)}")
print(f"❌ Classes only in val: {len(only_in_val)}")

# Optionally print or save mismatches
if only_in_train:
    print("\n🔍 Classes only in trainFiltered:")
    for cls in sorted(only_in_train):
        print(cls)

if only_in_val:
    print("\n🔍 Classes only in val:")
    for cls in sorted(only_in_val):
        print(cls)
