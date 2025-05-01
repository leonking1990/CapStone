import os
import json
import time
import csv
from datetime import datetime
from typing import Optional, Dict, Tuple, Any

import numpy as np
import tensorflow as tf

from tensorflow.keras.models import Sequential, load_model, Model
from tensorflow.keras.layers import (
    Conv2D, MaxPooling2D, Dense, Dropout, BatchNormalization, Input,
    GlobalAveragePooling2D
)
from tensorflow.keras.preprocessing.image import load_img, img_to_array
from tensorflow.keras.callbacks import (
    EarlyStopping, ModelCheckpoint, TensorBoard, CSVLogger, ReduceLROnPlateau
)
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.regularizers import l2
from tensorflow.keras.applications import EfficientNetV2B0
from tensorflow.keras.metrics import SparseTopKCategoricalAccuracy


class PlantCNNModel:
    """
    A class to create, train, load, and use a CNN model for plant classification.
    """

    def __init__(self,
                 input_shape: Tuple[int, int, int] = (224, 224, 3),
                 model_path: Optional[str] = None,
                 num_classes: Optional[int] = None,
                 class_indices: Optional[Dict[str, int]] = None,
                 use_pretrained: bool = False):
        """
        Initializes the model. Either loads from model_path or builds a new model.

        Args:
            input_shape: The shape of the input images (height, width, channels).
            model_path: Path to a .keras file to load an existing model.
            num_classes: The number of output classes (required if building new).
            class_indices: A dictionary mapping class names to indices
                           (required if building new, useful for loading too).
        """
        self.input_shape = input_shape
        self.model: Optional[tf.keras.Model] = None
        self.class_indices: Optional[Dict[str, int]] = None
        self.labels: Optional[Dict[int, str]] = None  # Map index to label name

        if model_path:
            # Fine-tune top 20 layers with low LR upon loading
            self._load_model(model_path, unfreeze_layers=20, fine_tune_lr=1e-5)

            # Load class indices
            if class_indices:
                self.class_indices = class_indices
                print(f"Using provided class indices dictionary.")
            else:
                self._load_class_indices(os.path.dirname(model_path))

            if self.class_indices:
                self.labels = {v: k for k, v in self.class_indices.items()}
                if self.model and self.model.output_shape[-1] != len(self.class_indices):
                    raise ValueError(
                        f"Loaded model output units ({self.model.output_shape[-1]}) "
                        f"does not match number of classes in indices ({len(self.class_indices)})"
                    )
            else:
                print(
                    "Warning: Could not load class indices. Prediction labels will be unavailable.")

        elif num_classes is not None and class_indices is not None and not use_pretrained:
            if len(class_indices) != num_classes:
                raise ValueError(
                    "Number of classes must match the length of class_indices.")
            print(f"Building a new model for {num_classes} classes.")
            self.class_indices = class_indices
            self.labels = {v: k for k, v in self.class_indices.items()}
            self.model = self._build_model(num_classes)
            self._compile_model()

        elif num_classes is not None and class_indices is not None and use_pretrained:
            if num_classes is not None and class_indices is not None:
                self.class_indices = class_indices
                self.labels = {v: k for k, v in self.class_indices.items()}
                self.model = self._build_pretrained_model(num_classes)
                self._compile_model()
            else:
                raise ValueError(
                    "When using a pre-trained model, 'num_classes' and 'class_indices' must be provided.")
        else:
            raise ValueError(
                "Must provide either 'model_path' to load or "
                "'num_classes' and 'class_indices' to build a new model."
            )

    def _build_model(self, num_classes: int) -> tf.keras.Model:
        """Builds the CNN model architecture."""
        # --- Configuration ---
        l2_strength = 0.001  # Define L2 strength for reuse
        dense_dropout_rate = 0.6  # Dropout for the main dense layer
        conv_dropout_rate_1 = 0.2  # Dropout after 3rd/4th conv blocks
        conv_dropout_rate_2 = 0.3  # Dropout after 5th conv block

        # Heuristic for dense layer size
        dense_units = min(4096, max(128, num_classes * 20))
        print(f"Calculated intermediate dense layer size: {dense_units} units")

        # --- Model Definition ---
        model = Sequential([
            Input(shape=self.input_shape, name="input_image"),

            # Block 1
            Conv2D(64, (3, 3), activation='relu', padding='same', name="conv1",
                   kernel_regularizer=l2(l2_strength)),
            BatchNormalization(name="bn1"),
            MaxPooling2D(pool_size=(2, 2), name="pool1"),
            Dropout(0.1),  # Optional: Add dropout here if needed ajust as needed

            # Block 2
            Conv2D(128, (3, 3), activation='relu', padding='same', name="conv2",
                   kernel_regularizer=l2(l2_strength)),
            BatchNormalization(name="bn2"),
            MaxPooling2D(pool_size=(2, 2), name="pool2"),
            Dropout(0.1),  # Optional: Add dropout here if needed ajust as needed

            # Block 3
            Conv2D(256, (3, 3), activation='relu', padding='same', name="conv3",
                   kernel_regularizer=l2(l2_strength)),
            BatchNormalization(name="bn3"),
            Dropout(conv_dropout_rate_1, name="dropout3"),
            MaxPooling2D(pool_size=(2, 2), name="pool3"),

            # Block 4
            Conv2D(512, (3, 3), activation='relu', padding='same', name="conv4",
                   kernel_regularizer=l2(l2_strength)),
            BatchNormalization(name="bn4"),
            Dropout(conv_dropout_rate_1, name="dropout4"),
            MaxPooling2D(pool_size=(2, 2), name="pool4"),

            # Block 5
            Conv2D(512, (3, 3), activation='relu', padding='same', name="conv5",
                   kernel_regularizer=l2(l2_strength)),
            BatchNormalization(name="bn5"),
            Dropout(conv_dropout_rate_2, name="dropout5"),
            MaxPooling2D(pool_size=(2, 2), name="pool5"),

            # Classifier Head
            GlobalAveragePooling2D(name="global_avg_pool"),

            Dense(dense_units, activation='relu', name="dense_intermediate",
                  kernel_regularizer=l2(l2_strength)),
            BatchNormalization(name="bn_dense"),
            Dropout(dense_dropout_rate, name="dropout_dense"),

            # Output Layer (Linear activation for from_logits=True in loss)
            # Ensure float32 for stability with mixed precision
            Dense(num_classes, activation='linear',
                  dtype='float32', name="output_logits")
        ], name="PlantCNNModel")

        return model

    def _build_pretrained_model(self, num_classes: int) -> tf.keras.Model:
        """Builds the model using a pre-trained base."""
        print(
            f"Building model with pre-trained base for {num_classes} classes.")

        # --- Instantiate Base Model ---
        # Load EfficientNetV2B0 pre-trained on ImageNet, without the top classification layer.
        # Ensure input_shape matches your data pipeline (e.g., 224x224x3)
        base_model = EfficientNetV2B0(
            include_top=False,          # Exclude ImageNet classifier head
            weights='imagenet',         # Load pre-trained weights
            input_shape=self.input_shape,
            # Keep feature map output
            pooling=None
        )

        # --- Freeze Base Model Layers ---
        # Prevent pre-trained weights from being updated during initial training
        base_model.trainable = False
        print(f"Base model ({base_model.name}) loaded and frozen.")

        # --- Create New Top Layers ---
        # Input to these layers is the output of the base_model
        inputs = base_model.input

        # We need to take the output of the base model
        x = base_model.output

        # Add pooling layer to reduce spatial dimensions
        x = GlobalAveragePooling2D(name="global_avg_pool")(x)

        # Optional: Add an intermediate dense layer for feature extraction i'm using for now
        x = Dense(512, activation='relu', name="dense_intermediate")(x)
        x = BatchNormalization()(x)
        x = Dropout(0.5)(x)  # Adjust dropout rate as needed

        # Final classification layer (logits)
        outputs = Dense(num_classes, activation='linear',
                        dtype='float32', name="output_logits")(x)

        # --- Combine Base and Top ---
        # Create the final model
        model = Model(inputs=inputs, outputs=outputs,
                      name="PlantCNNModel_Transfer")

        print("New classification head added.")
        return model

    def _compile_model(self, initial_lr: float = 0.0001):
        """Compiles the model with optimizer and loss."""
        if self.model is None:
            raise RuntimeError("Model has not been built or loaded yet.")

        # Initialize optimizer with a fixed learning rate
        # (ReduceLROnPlateau callback will adjust it during training)
        optimizer = Adam(learning_rate=initial_lr)

        # Wrap optimizer for mixed precision
        optimizer = tf.keras.mixed_precision.LossScaleOptimizer(optimizer)

        self.model.compile(
            optimizer=optimizer,
            loss=tf.keras.losses.SparseCategoricalCrossentropy(
                from_logits=True),
            metrics=['accuracy',
                     SparseTopKCategoricalAccuracy(k=5, name="top_5_accuracy"),
                     SparseTopKCategoricalAccuracy(k=10, name="top_10_accuracy")]
        )
        print(
            f"Model compiled with Adam optimizer (initial LR={initial_lr}) and SparseCategoricalCrossentropy loss.")

    def get_summary(self):
        """Prints the model summary."""
        if self.model:
            self.model.summary()
        else:
            print("No model loaded or built.")

    def train(self,
              train_generator: tf.data.Dataset,
              validation_generator: tf.data.Dataset,
              epochs: int,
              class_weight_dict: Optional[Dict[int, float]] = None,
              base_log_dir: str = "logs",
              base_model_dir: str = "models",
              model_name: Optional[str] = 'unnamed_model',
              ):
        """
        Trains the model.

        Args:
            train_generator: tf.data.Dataset for training.
            validation_generator: tf.data.Dataset for validation.
            epochs: Number of epochs to train.
            class_weight_dict: Optional dictionary mapping class indices to weights.
            base_log_dir: Base directory for TensorBoard and CSV logs.
            base_model_dir: Base directory for saving model checkpoints.
        """
        if self.model is None:
            raise RuntimeError(
                "Model must be built or loaded before training.")

        # --- Create Run-Specific Directories ---
        run_timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        run_log_dir = os.path.join(base_log_dir, f"{model_name}_{run_timestamp}")
        run_model_dir = os.path.join(base_model_dir, f"{model_name}_{run_timestamp}")
        os.makedirs(run_log_dir, exist_ok=True)
        os.makedirs(run_model_dir, exist_ok=True)
        print(f"Logging to: {run_log_dir}")
        print(f"Saving models to: {run_model_dir}")
        
        indices_path = os.path.join(run_model_dir, 'class_indices.json')
        try:
            with open(indices_path, 'w') as f:
                json.dump(self.class_indices, f, indent=4)
            print(f"✅ Saved class indices for this run to: {indices_path}")
        except Exception as e:
            # Log a warning but don't necessarily stop training
            print(f"\t⚠️ Warning: Could not save class indices for this run: {e}")

        # --- Define Callbacks ---
        # Model Checkpointing (Best and Latest)
        best_model_filepath = os.path.join(run_model_dir, "best_model.keras")
        latest_model_filepath = os.path.join(
            run_model_dir, "latest_checkpoint.keras")

        checkpoint_best = ModelCheckpoint(
            filepath=best_model_filepath, save_best_only=True,
            monitor='val_loss', mode='min', verbose=1
        )
        checkpoint_latest = ModelCheckpoint(
            filepath=latest_model_filepath, save_best_only=False,
            save_weights_only=False, verbose=0  # Save full model for resuming
        )

        # Early Stopping
        early_stop = EarlyStopping(
            monitor='val_loss', patience=15,  # Increased patience slightly
            mode='min', restore_best_weights=True, verbose=1
        )

        # Reduce Learning Rate on Plateau
        reduce_lr = ReduceLROnPlateau(
            monitor='val_loss', factor=0.2, patience=5, verbose=1,
            mode='min', min_delta=0.001, min_lr=1e-7
        )

        # TensorBoard Logging
        tensorboard_callback = TensorBoard(
            log_dir=run_log_dir, histogram_freq=1)

        # CSV Logging
        csv_log_path = os.path.join(run_log_dir, "training_log.csv")
        csv_logger = CSVLogger(csv_log_path, append=True)

        callback_list = [
            early_stop, checkpoint_best, checkpoint_latest,
            reduce_lr, tensorboard_callback, csv_logger
        ]
        # Uncomment the following line to include all callbacks
        # callback_list = [
        #     early_stop, checkpoint_best, checkpoint_latest,
        #     tensorboard_callback, csv_logger
        # ]

        # --- Save Class Weights to CSV ---
        if class_weight_dict:
            weights_csv_path = os.path.join(run_log_dir, "class_weights.csv")
            print(f"Saving class weights to: {weights_csv_path}")
            try:
                with open(weights_csv_path, 'w', newline='') as csvfile:
                    writer = csv.DictWriter(csvfile, fieldnames=[
                                            'ClassIndex', 'Weight'])
                    writer.writeheader()
                    for index, weight in sorted(class_weight_dict.items()):
                        writer.writerow(
                            {'ClassIndex': index, 'Weight': weight})
            except Exception as e:
                print(f"\tWarning: Could not save class weights to CSV: {e}")

        # --- Start Training ---
        for x, y in train_generator.take(1):
            print("✅ Sample image batch shape:", x.shape)
            print("✅ Sample label batch shape:", y.shape)
            print("✅ Label dtype:", y.dtype)
        print(f"\n--- Starting Training ---")
        history = self.model.fit(
            train_generator,
            epochs=epochs,
            validation_data=validation_generator,
            callbacks=callback_list,
            verbose=1,
            class_weight=class_weight_dict  # Pass class weights if available
        )
        print("✅ Training Completed!")
        return history

    def save_model(self, directory: str, filename: Optional[str] = None):
        """Saves the current model state."""
        if self.model is None:
            print("No model to save.")
            return

        os.makedirs(directory, exist_ok=True)
        
        fullfilename = f"{filename}_{time.strftime('%Y%m%d-%H%M%S')}.keras"
        filepath = os.path.join(directory, fullfilename)
        self.model.save(filepath)
        print(f"✅ Model saved at: {filepath}")

        # Also save class indices alongside the model
        if self.class_indices:
            indices_path = os.path.join(directory, f'{filename}_class_indices.json')
            try:
                with open(indices_path, 'w') as f:
                    json.dump(self.class_indices, f, indent=4)
                print(f"✅ Saved class indices to {indices_path}")
            except Exception as e:
                print(f"\tWarning: Could not save class indices: {e}")

    def _load_model(self, model_path: str, unfreeze_layers: int = 0, fine_tune_lr: float = 1e-5):
        """Loads a Keras model from the specified path, with optional fine-tuning."""
        if os.path.exists(model_path):
            print(f"Loading model from {model_path}...")
            # Don't recompile yet
            self.model = load_model(model_path, compile=False)
            print(f"✅ Model loaded successfully.")

            # Fine-tune top N layers if specified 
            if unfreeze_layers > 0:
                try:
                    # Assuming first layer is EfficientNet base
                    base_model = self.model.layers[0]
                    if hasattr(base_model, 'layers'):
                        for layer in base_model.layers[-unfreeze_layers:]:
                            layer.trainable = True
                        print(
                            f"🔓 Unfroze the top {unfreeze_layers} layers for fine-tuning.")
                    else:
                        print(
                            "⚠️ Warning: Could not locate base model layers to unfreeze.")
                except Exception as e:
                    print(f"⚠️ Error during fine-tuning setup: {e}")

            # Recompile regardless (in case optimizer/loss/metrics need updating)
            optimizer = tf.keras.optimizers.Adam(learning_rate=fine_tune_lr)
            optimizer = tf.keras.mixed_precision.LossScaleOptimizer(optimizer)

            self.model.compile(
                optimizer=optimizer,
                loss=tf.keras.losses.SparseCategoricalCrossentropy(
                    from_logits=True),
                metrics=['accuracy',
                         SparseTopKCategoricalAccuracy(k=5, name="top_5_accuracy"),
                         SparseTopKCategoricalAccuracy(k=10, name="top_10_accuracy")]
            )
            print(f"🔁 Model recompiled (fine_tune_lr={fine_tune_lr})")
        else:
            raise FileNotFoundError(
                f"❌ Error: Model file '{model_path}' not found!")

    def _load_class_indices(self, directory: str):
        """Loads class indices from a JSON file in the specified directory."""
        indices_path = os.path.join(directory, 'class_indices.json')
        if os.path.exists(indices_path):
            try:
                with open(indices_path, 'r') as f:
                    self.class_indices = json.load(f)
                    # Convert keys back to int if needed (JSON saves keys as strings)
                    # self.class_indices = {int(k): v for k, v in self.class_indices.items()}
                print(f"Loaded class indices from {indices_path}")
            except Exception as e:
                print(
                    f"\tWarning: Could not load or parse class indices file '{indices_path}': {e}")
                self.class_indices = None
        else:
            print(
                f"Warning: Class indices file not found at '{indices_path}'.")
            self.class_indices = None

    def predict(self, image_path: str) -> Tuple[Optional[str], Optional[float]]:
        """
        Predicts the class label for a single image file.

        Args:
            image_path: Path to the input image file.

        Returns:
            A tuple containing:
                - Predicted class name (str) or None if labels are unavailable.
                - Confidence score (float) or None if prediction fails.
        """
        if self.model is None:
            print("Error: Model not loaded or built.")
            return None, None
        if self.labels is None:
            print("Warning: Class labels unavailable. Returning index instead of name.")

        try:
            img = load_img(image_path, target_size=self.input_shape[:2])
            img_array = img_to_array(img) / 255.0
            img_array = np.expand_dims(
                img_array, axis=0)  # Add batch dimension

            # Get prediction for the single image
            predictions = self.model.predict(img_array)[0]

            # Apply softmax if using linear output (from_logits=True in loss)
            # Use float32 for softmax calculation
            confidence_scores = tf.nn.softmax(
                tf.cast(predictions, tf.float32)).numpy()

            predicted_class_index = np.argmax(confidence_scores)
            # Get confidence of the top prediction
            confidence = float(confidence_scores[predicted_class_index])

            # Get class name using the loaded labels dictionary
            predicted_class_name = self.labels.get(predicted_class_index, str(
                predicted_class_index))  # Fallback to index if no label

            print(
                f"Predicted Species: {predicted_class_name} (Confidence: {confidence:.4f})")
            return predicted_class_name, confidence

        except Exception as e:
            print(f"Error during prediction for image {image_path}: {e}")
            return None, None

    def deploy(self, deploy_directory: str = "saved_model/PlantClassifier"):
        """ Saves the model in TensorFlow SavedModel format for deployment. """
        if self.model is None:
            print("No model available to deploy.")
            return

        # Add a version number or timestamp to the deployment directory
        version = datetime.now().strftime("%Y%m%d%H%M%S")
        save_dir = f"{deploy_directory}_v{version}"
        try:
            tf.saved_model.save(self.model, save_dir)
            print(
                f"✅ Model successfully saved in SavedModel format for deployment at: {save_dir}")
        except Exception as e:
            print(f"❌ Error saving model in SavedModel format: {e}")
