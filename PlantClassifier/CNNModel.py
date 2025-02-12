import os
import numpy as np
import tensorflow as tf
from tensorflow.keras.models import Sequential, load_model
from tensorflow.keras.layers import Conv2D, MaxPooling2D, Flatten, Dense, Dropout, BatchNormalization, Input
from tensorflow.keras.preprocessing.image import load_img, img_to_array
from tensorflow.keras.mixed_precision import set_global_policy
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint
import time
from datetime import datetime

# Enable Mixed Precision
set_global_policy('mixed_float16')
 

class CreateModel:
    def __init__(self, train_generator=None, model_path=None):
        """Initialize CNN model or load an existing model."""
        if model_path:            
            self.load(model_path)            
        elif train_generator:
            num_classes = len(train_generator.class_indices)
            
            # Batch Size & Learning Rate Scaling
            base_lr = 0.001  # Default for batch_size=32
            batch_size = 64  # Adjust as needed
            new_lr = base_lr * (batch_size / 32)

            lr_schedule = tf.keras.optimizers.schedules.ExponentialDecay(
                initial_learning_rate=new_lr,
                decay_steps=1000,
                decay_rate=0.9
            )
            optimizer = tf.keras.optimizers.Adam(learning_rate=lr_schedule)
            optimizer = tf.keras.mixed_precision.LossScaleOptimizer(optimizer)

            # Define CNN Model            
            self.model = Sequential([
                Input(shape=(224, 224, 3)),  

                Conv2D(64, (3,3), activation='relu'),
                BatchNormalization(),
                Dropout(0.2),  # ✅ Prevents overfitting in Conv Layers
                MaxPooling2D(pool_size=(2,2)),

                Conv2D(128, (3,3), activation='relu'),
                BatchNormalization(),
                Dropout(0.2),
                MaxPooling2D(pool_size=(2,2)),

                Conv2D(256, (3,3), activation='relu'),
                BatchNormalization(),
                Dropout(0.2),
                MaxPooling2D(pool_size=(2,2)),

                Conv2D(512, (3,3), activation='relu'),
                BatchNormalization(),
                Dropout(0.2),
                MaxPooling2D(pool_size=(2,2)),

                Flatten(),

                Dense(512, activation='relu'),
                Dropout(0.5),  # ✅ Prevents overfitting in Fully Connected Layers
                Dense(256, activation='relu'),
                Dropout(0.5),

                Dense(num_classes, activation='softmax', dtype='float32')  # ✅ Avoids precision issues
            ])
            

            self.model.compile(optimizer=optimizer, loss='categorical_crossentropy', metrics=['accuracy'])
            self.class_indices = train_generator.class_indices  # Store label mappings
            self.labels = {v: k for k, v in self.class_indices.items()}  # Reverse mapping
        else:
            raise ValueError("❌ Error: Either provide a train_generator or a model_path.")

    # def train(self, train_generator, validation_generator, epochs=10):
    #     """ Train the model with given data. """
    #     gpus = tf.config.experimental.list_physical_devices('GPU')

    #     if gpus:
    #         print(f"✅ TensorFlow detected {len(gpus)} GPU(s):")
    #         for gpu in gpus:
    #             print(f" - {gpu}")
    #     else:
    #         print("❌ No GPU detected. TensorFlow is running on CPU.")

    #     # Callbacks
    #     early_stop = EarlyStopping(monitor='val_loss', patience=5, restore_best_weights=True)
    #     checkpoint = ModelCheckpoint("best_model.keras", save_best_only=True, monitor="val_loss", mode="min")

    #     self.model.fit(train_generator, validation_data=validation_generator, epochs=epochs, callbacks=[early_stop, checkpoint])
    
    def train(self, train_generator, validation_generator, epochs=10):
        """ Train the model only between 12 AM - 7 AM. """
        
        # Callbacks for early stopping & best model saving
        checkpoint = ModelCheckpoint("best_model.keras", save_best_only=True, monitor="val_loss", mode="min")
        early_stop = EarlyStopping(monitor='val_loss', patience=5, restore_best_weights=True)

        for epoch in range(epochs):
            current_time = datetime.now().time()  # Get current time
            start_hour = 0  # 12 AM (midnight)
            end_hour = 7  # 7 AM

            # If it's outside 12 AM - 7 AM, pause training
            while not (start_hour <= current_time.hour < end_hour):
                print(f"⏸️ Pausing training at {current_time}. Waiting until midnight to resume...")
                time.sleep(60 * 10)  # Sleep for 10 minutes before checking again
                current_time = datetime.now().time()  # Update current time
            
            print(f"🚀 Resuming training: Epoch {epoch+1}/{epochs} at {current_time} (A100 Available)")

            # Train one epoch at a time
            self.model.fit(train_generator, validation_data=validation_generator, epochs=1, callbacks=[early_stop, checkpoint])

            # Save the model after every epoch
            self.save(f"checkpoint_epoch_{epoch+1}.keras")

        print("✅ Training Completed!")

    def save(self, filename=None):
        """ Save the trained model with a timestamp. """
        if filename is None:
            filename = f"plant_classifier_{time.strftime('%Y%m%d-%H%M%S')}.keras"
        
        self.model.save(filename)
        print(f"✅ Model saved as {filename}")

    def load(self, filename="plant_classifier.keras"):
        """ Load a pre-trained model. """
        if os.path.exists(filename):
            self.model = load_model(filename)
            print(f"✅ Model loaded from {filename}")
        else:
            raise FileNotFoundError(f"❌ Error: Model file '{filename}' not found!")

    def predict(self, image_path):
        """Predict the species of a given plant image."""
        img = load_img(image_path, target_size=(224, 224))  # Resize to match model input
        img_array = img_to_array(img) / 255.0  # Normalize
        img_array = np.expand_dims(img_array, axis=0)  # Add batch dimension

        predictions = self.model.predict(img_array)
        predicted_class_index = np.argmax(predictions)  # Get highest probability index
        predicted_class_name = self.labels.get(predicted_class_index, "Unknown")

        print(f"Predicted Species: {predicted_class_name}")
        return predicted_class_name

    