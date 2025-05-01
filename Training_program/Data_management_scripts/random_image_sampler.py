import os
import shutil
import random
import sys

# ==== CONFIGURATION ====
BASE_DIR = "/research/PlantDataset/PlantCLEF2024"
TRAIN_SRC = os.path.join(BASE_DIR, "trainFiltered")
VAL_SRC = os.path.join(BASE_DIR, "valFiltered")
RANDOM_DEST = os.path.join(BASE_DIR, "randomImages")
TRAIN_DEST = os.path.join(RANDOM_DEST, "trainFiltered")
VAL_DEST = os.path.join(RANDOM_DEST, "valFiltered")


def clear_random_images():
    """Deletes everything inside the randomImages folder."""
    if os.path.exists(RANDOM_DEST):
        shutil.rmtree(RANDOM_DEST)
        print("🧹 Cleared randomImages folder.")
    else:
        print("⚠️ Nothing to clear. Folder does not exist.")


def sample_images_from_classes(src_dir, dest_dir, class_list, images_per_class=10):
    """
    Copies `images_per_class` images from each class in `class_list`
    from `src_dir` to the same structure in `dest_dir`.
    """
    os.makedirs(dest_dir, exist_ok=True)

    for cls in class_list:
        src_class_path = os.path.join(src_dir, cls)
        dest_class_path = os.path.join(dest_dir, cls)

        if not os.path.exists(src_class_path):
            print(f"⚠️ Skipping missing class in {src_dir}: {cls}")
            continue

        os.makedirs(dest_class_path, exist_ok=True)

        images = [
            f for f in os.listdir(src_class_path)
            if os.path.isfile(os.path.join(src_class_path, f))
        ]

        if not images:
            print(f"⚠️ No images found in {src_class_path}")
            continue

        selected_images = random.sample(images, min(images_per_class, len(images)))

        for img in selected_images:
            shutil.copy2(os.path.join(src_class_path, img), os.path.join(dest_class_path, img))


def main():
    
    if len(sys.argv) > 1:
        arg = sys.argv[1]

        if arg == "clear":
            clear_random_images()
            return
        elif arg == "help":
            print("Usage: python random_image_sampler.py [clear|<number_of_images_per_class>]")
            print("  clear: Clears the randomImages folder.")
            print("  <number_of_images_per_class>: Number of images to sample from each class.")
            return
        else:
            try:
                images_per_class = int(arg)
            except ValueError:
                print(f"❌ Invalid argument: {arg}")
                print("Use 'help' for usage info.")
                return
    else:
        images_per_class = 10  # Default value

    # Get all class folders from trainFiltered
    train_classes = [
        d for d in os.listdir(TRAIN_SRC)
        if os.path.isdir(os.path.join(TRAIN_SRC, d))
    ]

    # Pick 10 random class folders
    selected_classes = random.sample(train_classes, min(10, len(train_classes)))
    print("📦 Selected classes:", selected_classes)

    # Sample from the same classes in both train and val
    sample_images_from_classes(TRAIN_SRC, TRAIN_DEST, selected_classes, images_per_class=images_per_class)
    sample_images_from_classes(VAL_SRC, VAL_DEST, selected_classes, images_per_class=images_per_class)

    print("✅ Sampled 10 random images from the SAME 10 classes in both train and val.")


if __name__ == "__main__":
    main()
