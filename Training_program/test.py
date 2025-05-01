from tf_data_pipeline_new import create_tf_dataset
import tensorflow as tf
import os




# --- Example Usage (Optional: Comment out or remove in final script) ---
if __name__ == "__main__":
    print("Example Usage:")
    # Dummy preprocessing function
    def dummy_preprocess(img):
        return img / 255.0

    # Example for PlantClassifier
    print("\nTesting PlantClassifier...")
    # Create dummy dirs/files if they don't exist
    dummy_plant_dir = "dummy_plant_data/train"
    os.makedirs(os.path.join(dummy_plant_dir, "Rose"), exist_ok=True)
    os.makedirs(os.path.join(dummy_plant_dir, "Tulip"), exist_ok=True)
    with open(os.path.join(dummy_plant_dir, "Rose", "rose1.jpg"), "w") as f: f.write("")
    with open(os.path.join(dummy_plant_dir, "Tulip", "tulip1.jpg"), "w") as f: f.write("")

    try:
        ds_plant, names_plant, indices_plant, weights_plant = create_tf_dataset(
            dir_path=dummy_plant_dir,
            batch_size=2,
            preprocessing_fn=dummy_preprocess,
            model="PlantClassifier",
            is_training=True,
            return_labels_weights=True
        )
        print("PlantClassifier Dataset:", ds_plant)
        print("Class Names:", names_plant)
        print("Class Indices:", indices_plant)
        print("Class Weights:", weights_plant)
        # print("First batch:", next(iter(ds_plant)))
    except Exception as e:
        print(f"Error testing PlantClassifier: {e}")

    # Example for HealthDetector
    print("\nTesting HealthDetector...")
     # Create dummy dirs/files if they don't exist
    # dummy_health_dir = "dummy_health_data/train"
    # os.makedirs(os.path.join(dummy_health_dir, "Apple_healthy"), exist_ok=True)
    # os.makedirs(os.path.join(dummy_health_dir, "Apple_scab"), exist_ok=True)
    # # Need actual images for image_dataset_from_directory, creating dummy png
    # dummy_img = tf.zeros([10, 10, 3], dtype=tf.uint8)
    # tf.io.write_file(os.path.join(dummy_health_dir, "Apple_healthy", "healthy1.png"), tf.image.encode_png(dummy_img))
    # tf.io.write_file(os.path.join(dummy_health_dir, "Apple_scab", "scab1.png"), tf.image.encode_png(dummy_img))
    
    my_specific_path = "/research"

    base_dataset_path = os.path.join(my_specific_path, 'New Plant Diseases Dataset(Augmented)', 'New Plant Diseases Dataset(Augmented)')
    
    original_train_dir = os.path.join(base_dataset_path, 'train')
    original_valid_dir = os.path.join(base_dataset_path, 'valid')

    try:
        ds_health, names_health, indices_health, weights_health = create_tf_dataset(
            dir_path=original_train_dir,
            batch_size=2,
            preprocessing_fn=dummy_preprocess, # Can be None if default scaling is okay
            model="HealthDetector",
            is_training=True,
            return_labels_weights=True,
             # Use subset for training/validation split
            validation_split=0.0 # Use 0 split just for testing structure
        )
        print("HealthDetector Dataset:", ds_health)
        print("Class Names:", names_health) # Should be ['healthy', 'unhealthy']
        print("Class Indices:", indices_health) # Should be {'healthy': 0, 'unhealthy': 1}
        print("Class Weights:", weights_health)
        # print("First batch:", next(iter(ds_health)))
    except Exception as e:
        print(f"Error testing HealthDetector: {e}")

