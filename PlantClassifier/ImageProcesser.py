import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator

# Define directories
train_dir = "/research/PlantDataset/PlantCLEF2024/train"
val_dir = "/research/PlantDataset/PlantCLEF2024/val"
test_dir = "/research/PlantDataset/PlantCLEF2024/test"


class ImageDataset:
    def __init__(self):
        """Initialize data generators with proper augmentation and preprocessing."""
        # Image augmentation for training data
        self.train_datagen = ImageDataGenerator(
            rescale=1.0/255,        # Normalize pixel values
            rotation_range=20,      # Rotate images randomly
            width_shift_range=0.2,  # Horizontal shifts
            height_shift_range=0.2, # Vertical shifts
            shear_range=0.2,        # Shear transformations
            zoom_range=0.2,         # Random zoom
            horizontal_flip=True,   # Flip images horizontally
            fill_mode="nearest"     # Fill missing pixels
        )

        # Validation and test sets should NOT be augmented (only rescaled)
        self.val_test_datagen = ImageDataGenerator(rescale=1.0/255)

    def create_training_data(self):
        """Create a training dataset with augmentation."""
        return self.train_datagen.flow_from_directory(
            train_dir,
            target_size=(224, 224),
            batch_size=64,
            class_mode='categorical',
            shuffle=True,   # To shuffle for training
            seed=42         # Set seed for reproducibility ask prf Sam about this
        )

    def create_validation_data(self):
        """Create a validation dataset without augmentation."""
        return self.val_test_datagen.flow_from_directory(
            val_dir,
            target_size=(224, 224),
            batch_size=64,
            class_mode='categorical',
            shuffle=False,  # No shuffling for validation
            seed=42
        )

    def create_test_data(self):
        """Create a test dataset without augmentation."""
        return self.val_test_datagen.flow_from_directory(
            test_dir,
            target_size=(224, 224),
            batch_size=64,
            class_mode='categorical',
            shuffle=False,  # No shuffling for testing
            seed=42
        )

