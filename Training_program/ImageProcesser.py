import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
import cv2
import numpy as np
import json

def to_float32(x):
    """Ensure images are in float32 format for mixed precision training."""
    return np.array(x, dtype=np.float32)

class ImageDataset:
    def __init__(self, isSmall):
        """Initialize data generators with proper augmentation and preprocessing."""
        # Define directories
        self.class_indices = None  # Save class indices
        self.inverse_class_indices = None  # For reverse lookup
        if isSmall:
            self.train_dir = "/research/PlantDataset/small_dataset/train"
            self.val_dir = "/research/PlantDataset/small_dataset/val/"
            self.test_dir = "/research/PlantDataset/small_dataset/test"
        else:
            self.train_dir = "/research/PlantDataset/PlantCLEF2024/train"
            self.val_dir = "/research/PlantDataset/PlantCLEF2024/val"
            self.test_dir = "/research/PlantDataset/PlantCLEF2024/test"

        # Image augmentation for training data
        # augmentation is used to increase the diversity of the training dataset
        # by applying random transformations to the images
        # uncomment the lines below to apply augmentation 
        self.train_datagen = ImageDataGenerator(
            # change and value to suit your needs
            rescale=1.0/255,        
            # rotation_range=20, # Rotate images by 20 degrees
            # width_shift_range=0.2,  # Shift images horizontally
            # height_shift_range=0.2, # Shift images vertically
            # shear_range=0.2,        # Shear transformation
            # zoom_range=0.2,         # Zoom in/out
            # horizontal_flip=True,   # Flip images horizontally
            # fill_mode="nearest",    # Fill empty pixels after transformations
            # brightness_range=[0.7, 1.3],  # Adjust brightness
            # channel_shift_range=50.0,  # Changes RGB channels
            preprocessing_function=self.preprocess_with_padding  # Add padding function
        )

        # Validation and test sets should NOT be augmented (only rescaled + padding)
        self.val_test_datagen = ImageDataGenerator(
            rescale=1.0/255,
            preprocessing_function=self.preprocess_with_padding  # ✅ Add padding function
        )

    def preprocess_with_padding(self, img):
        """Pads an image to make it square before resizing to (224, 224)."""
        h, w, c = img.shape  # Get height, width, and channels
        size = max(h, w)  # Find the largest dimension
        
        # Create a square black canvas (0s = black background)
        padded_img = np.zeros((size, size, c), dtype=np.float32)
        
        # Center the original image on the canvas
        x_offset = (size - w) // 2
        y_offset = (size - h) // 2
        padded_img[y_offset:y_offset + h, x_offset:x_offset + w] = img #.astype(np.float32)
        
        # Resize to (224, 224)
        padded_resized = cv2.resize(padded_img, (224, 224)).astype(np.float32)
        
        return padded_resized

    def create_training_data(self):
        """Create a training dataset with augmentation."""
        train_data = self.train_datagen.flow_from_directory(
            self.train_dir,
            target_size=(224, 224),
            batch_size=128,
            class_mode='sparse',
            shuffle=True,
            seed=42,
        )
        # Save the class indices and inverse mapping
        self.class_indices = train_data.class_indices
        self.inverse_class_indices = {v: k for k, v in train_data.class_indices.items()}
        with open('class_indices.json', 'w') as f:
            json.dump(train_data.class_indices, f)

        print("✅ Generated class_indices.json successfully!")
        return train_data

    def create_validation_data(self):
        """Create a validation dataset without augmentation."""
        val_data = self.val_test_datagen.flow_from_directory(
            self.val_dir,
            target_size=(224, 224),
            batch_size=128,
            class_mode='sparse',
            shuffle=False,
            seed=42,
        )
        # Use the same class indices as training
        val_data.class_indices = self.class_indices
        return val_data

    def create_test_data(self):
        """Create a test dataset without augmentation."""
        test_data = self.val_test_datagen.flow_from_directory(
            self.test_dir,
            target_size=(224, 224),
            batch_size=128,
            class_mode='sparse',
            shuffle=False,
            seed=42,
        )
        # Use the same class indices as training
        test_data.class_indices = self.class_indices
        return test_data
    
    def get_folder_name_from_index(self, predicted_index):
        """Convert predicted index to actual folder name (plant ID)."""
        if self.inverse_class_indices is None:
            raise ValueError("Class mappings not loaded. Run create_training_data() first.")
        return self.inverse_class_indices.get(predicted_index, "Unknown")
