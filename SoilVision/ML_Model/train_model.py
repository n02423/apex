#!/usr/bin/env python3
"""
SoilVision ML Model Training Script

This script trains a CNN model for soil type classification.
It supports 6 soil types: clay, loam, sandy, silt, peat, chalk

Requirements:
- TensorFlow 2.x
- OpenCV
- NumPy
- Matplotlib
- scikit-learn
- coremltools (for iOS conversion)

Usage:
    python train_model.py --data_dir ./dataset --output_dir ./model_outputs
"""

import os
import sys
import argparse
import json
import numpy as np
import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.models import Sequential, load_model
from tensorflow.keras.layers import Conv2D, MaxPooling2D, Flatten, Dense, Dropout, BatchNormalization
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau, ModelCheckpoint
from sklearn.metrics import classification_report, confusion_matrix
import matplotlib.pyplot as plt
import cv2
from datetime import datetime

# Soil types for classification
SOIL_TYPES = ['clay', 'loam', 'sandy', 'silt', 'peat', 'chalk']
NUM_CLASSES = len(SOIL_TYPES)
IMG_SIZE = (224, 224)
BATCH_SIZE = 32
EPOCHS = 50

class SoilClassifierTrainer:
    def __init__(self, data_dir, output_dir):
        self.data_dir = data_dir
        self.output_dir = output_dir
        self.model = None
        self.history = None

        # Create output directory
        os.makedirs(output_dir, exist_ok=True)

        # Set random seeds for reproducibility
        np.random.seed(42)
        tf.random.set_seed(42)

        print(f"🌱 SoilVision ML Trainer Initialized")
        print(f"📁 Data directory: {data_dir}")
        print(f"💾 Output directory: {output_dir}")
        print(f"🎯 Soil types: {SOIL_TYPES}")

    def validate_dataset(self):
        """Validate that the dataset structure is correct"""
        print("\n🔍 Validating dataset structure...")

        if not os.path.exists(self.data_dir):
            raise FileNotFoundError(f"Data directory not found: {self.data_dir}")

        required_classes = set(SOIL_TYPES)
        found_classes = set()

        for soil_type in SOIL_TYPES:
            class_dir = os.path.join(self.data_dir, soil_type)
            if os.path.exists(class_dir):
                images = [f for f in os.listdir(class_dir)
                         if f.lower().endswith(('.jpg', '.jpeg', '.png', '.bmp'))]
                found_classes.add(soil_type)
                print(f"  ✅ {soil_type}: {len(images)} images")
            else:
                print(f"  ❌ {soil_type}: Directory not found")

        missing_classes = required_classes - found_classes
        if missing_classes:
            raise ValueError(f"Missing soil type directories: {missing_classes}")

        print(f"✅ Dataset validation complete. Found {len(found_classes)}/{NUM_CLASSES} classes.")
        return True

    def create_data_generators(self, validation_split=0.2):
        """Create training and validation data generators"""
        print("\n📊 Creating data generators...")

        # Training data generator with augmentation
        train_datagen = ImageDataGenerator(
            rescale=1./255,
            rotation_range=20,
            width_shift_range=0.2,
            height_shift_range=0.2,
            shear_range=0.2,
            zoom_range=0.2,
            horizontal_flip=True,
            vertical_flip=True,
            brightness_range=[0.8, 1.2],
            contrast_range=[0.8, 1.2],
            fill_mode='nearest',
            validation_split=validation_split
        )

        # Validation data generator (no augmentation)
        val_datagen = ImageDataGenerator(
            rescale=1./255,
            validation_split=validation_split
        )

        # Create generators
        train_generator = train_datagen.flow_from_directory(
            self.data_dir,
            target_size=IMG_SIZE,
            batch_size=BATCH_SIZE,
            class_mode='categorical',
            subset='training',
            shuffle=True,
            seed=42
        )

        validation_generator = val_datagen.flow_from_directory(
            self.data_dir,
            target_size=IMG_SIZE,
            batch_size=BATCH_SIZE,
            class_mode='categorical',
            subset='validation',
            shuffle=False,
            seed=42
        )

        print(f"📈 Training samples: {train_generator.samples}")
        print(f"📊 Validation samples: {validation_generator.samples}")
        print(f"🏷️  Class indices: {train_generator.class_indices}")

        return train_generator, validation_generator

    def build_model(self):
        """Build the CNN model architecture"""
        print("\n🏗️  Building CNN model...")

        model = Sequential([
            # First convolutional block
            Conv2D(32, (3, 3), activation='relu', input_shape=(*IMG_SIZE, 3)),
            BatchNormalization(),
            Conv2D(32, (3, 3), activation='relu'),
            BatchNormalization(),
            MaxPooling2D(2, 2),
            Dropout(0.25),

            # Second convolutional block
            Conv2D(64, (3, 3), activation='relu'),
            BatchNormalization(),
            Conv2D(64, (3, 3), activation='relu'),
            BatchNormalization(),
            MaxPooling2D(2, 2),
            Dropout(0.25),

            # Third convolutional block
            Conv2D(128, (3, 3), activation='relu'),
            BatchNormalization(),
            Conv2D(128, (3, 3), activation='relu'),
            BatchNormalization(),
            MaxPooling2D(2, 2),
            Dropout(0.25),

            # Fourth convolutional block
            Conv2D(256, (3, 3), activation='relu'),
            BatchNormalization(),
            Conv2D(256, (3, 3), activation='relu'),
            BatchNormalization(),
            MaxPooling2D(2, 2),
            Dropout(0.25),

            # Flatten and dense layers
            Flatten(),
            Dense(512, activation='relu'),
            BatchNormalization(),
            Dropout(0.5),
            Dense(256, activation='relu'),
            BatchNormalization(),
            Dropout(0.4),
            Dense(NUM_CLASSES, activation='softmax')
        ])

        # Compile the model
        model.compile(
            optimizer=Adam(learning_rate=0.001),
            loss='categorical_crossentropy',
            metrics=['accuracy', 'top_k_categorical_accuracy']
        )

        # Print model summary
        model.summary()

        self.model = model
        return model

    def setup_callbacks(self):
        """Setup training callbacks"""
        print("\n⚙️  Setting up training callbacks...")

        callbacks = [
            # Early stopping to prevent overfitting
            EarlyStopping(
                monitor='val_loss',
                patience=10,
                restore_best_weights=True,
                verbose=1
            ),

            # Learning rate reduction
            ReduceLROnPlateau(
                monitor='val_loss',
                factor=0.5,
                patience=5,
                min_lr=1e-7,
                verbose=1
            ),

            # Model checkpoint
            ModelCheckpoint(
                filepath=os.path.join(self.output_dir, 'best_model.h5'),
                monitor='val_accuracy',
                save_best_only=True,
                verbose=1
            )
        ]

        return callbacks

    def train_model(self, train_generator, validation_generator):
        """Train the model"""
        print("\n🚀 Starting model training...")

        callbacks = self.setup_callbacks()

        # Calculate steps per epoch
        steps_per_epoch = max(1, train_generator.samples // BATCH_SIZE)
        validation_steps = max(1, validation_generator.samples // BATCH_SIZE)

        print(f"📏 Steps per epoch: {steps_per_epoch}")
        print(f"📏 Validation steps: {validation_steps}")

        # Train the model
        history = self.model.fit(
            train_generator,
            steps_per_epoch=steps_per_epoch,
            epochs=EPOCHS,
            validation_data=validation_generator,
            validation_steps=validation_steps,
            callbacks=callbacks,
            verbose=1
        )

        self.history = history
        return history

    def evaluate_model(self, validation_generator):
        """Evaluate the trained model"""
        print("\n📊 Evaluating model performance...")

        # Get predictions
        validation_steps = max(1, validation_generator.samples // BATCH_SIZE)
        predictions = self.model.predict(validation_generator, steps=validation_steps)
        predicted_classes = np.argmax(predictions, axis=1)
        true_classes = validation_generator.classes[:len(predicted_classes)]
        class_labels = list(validation_generator.class_indices.keys())

        # Print classification report
        print("\n📋 Classification Report:")
        print(classification_report(true_classes, predicted_classes, target_names=class_labels))

        # Generate confusion matrix
        cm = confusion_matrix(true_classes, predicted_classes)
        self.plot_confusion_matrix(cm, class_labels)

        # Calculate final metrics
        final_accuracy = np.mean(true_classes == predicted_classes)
        print(f"🎯 Final Accuracy: {final_accuracy:.4f} ({final_accuracy*100:.2f}%)")

        return {
            'accuracy': final_accuracy,
            'classification_report': classification_report(true_classes, predicted_classes, target_names=class_labels),
            'confusion_matrix': cm.tolist()
        }

    def plot_confusion_matrix(self, cm, class_names):
        """Plot and save confusion matrix"""
        plt.figure(figsize=(10, 8))
        plt.imshow(cm, interpolation='nearest', cmap=plt.cm.Blues)
        plt.title('Soil Classification Confusion Matrix')
        plt.colorbar()

        tick_marks = np.arange(len(class_names))
        plt.xticks(tick_marks, class_names, rotation=45)
        plt.yticks(tick_marks, class_names)

        # Add text annotations
        thresh = cm.max() / 2.
        for i, j in np.ndindex(cm.shape):
            plt.text(j, i, format(cm[i, j], 'd'),
                    horizontalalignment="center",
                    color="white" if cm[i, j] > thresh else "black")

        plt.tight_layout()
        plt.ylabel('True label')
        plt.xlabel('Predicted label')
        plt.savefig(os.path.join(self.output_dir, 'confusion_matrix.png'), dpi=150, bbox_inches='tight')
        plt.close()

    def plot_training_history(self):
        """Plot and save training history"""
        if not self.history:
            return

        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 5))

        # Plot training & validation accuracy
        ax1.plot(self.history.history['accuracy'], label='Training Accuracy')
        ax1.plot(self.history.history['val_accuracy'], label='Validation Accuracy')
        ax1.set_title('Model Accuracy')
        ax1.set_xlabel('Epoch')
        ax1.set_ylabel('Accuracy')
        ax1.legend()
        ax1.grid(True)

        # Plot training & validation loss
        ax2.plot(self.history.history['loss'], label='Training Loss')
        ax2.plot(self.history.history['val_loss'], label='Validation Loss')
        ax2.set_title('Model Loss')
        ax2.set_xlabel('Epoch')
        ax2.set_ylabel('Loss')
        ax2.legend()
        ax2.grid(True)

        plt.tight_layout()
        plt.savefig(os.path.join(self.output_dir, 'training_history.png'), dpi=150, bbox_inches='tight')
        plt.close()

    def save_model_and_metadata(self, evaluation_results):
        """Save the trained model and metadata"""
        print("\n💾 Saving model and metadata...")

        # Save the final model
        model_path = os.path.join(self.output_dir, 'soil_classifier_model.h5')
        self.model.save(model_path)
        print(f"✅ Model saved to: {model_path}")

        # Save model metadata
        metadata = {
            'model_name': 'SoilVision Classifier',
            'version': '1.0.0',
            'created_date': datetime.now().isoformat(),
            'soil_types': SOIL_TYPES,
            'num_classes': NUM_CLASSES,
            'input_shape': [*IMG_SIZE, 3],
            'training_data': self.data_dir,
            'evaluation_results': evaluation_results,
            'hyperparameters': {
                'batch_size': BATCH_SIZE,
                'epochs': EPOCHS,
                'image_size': IMG_SIZE,
                'validation_split': 0.2
            }
        }

        metadata_path = os.path.join(self.output_dir, 'model_metadata.json')
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        print(f"✅ Metadata saved to: {metadata_path}")

    def convert_to_coreml(self):
        """Convert the trained model to CoreML format for iOS"""
        print("\n🍎 Converting model to CoreML format...")

        try:
            import coremltools as ct

            # Load the trained model
            model_path = os.path.join(self.output_dir, 'soil_classifier_model.h5')
            model = load_model(model_path)

            # Convert to CoreML
            classifier_config = ct.ClassifierConfig(class_labels=SOIL_TYPES)

            coreml_model = ct.convert(
                model,
                inputs=[ct.ImageType(name="input", shape=(*IMG_SIZE, 3), scale=1/255.0)],
                classifier_config=classifier_config
            )

            # Set model metadata
            coreml_model.short_description = "Soil type classification model"
            coreml_model.author = "SoilVision"
            coreml_model.license = "MIT"
            coreml_model.version = "1.0"

            # Save CoreML model
            coreml_path = os.path.join(self.output_dir, 'SoilClassifier.mlmodel')
            coreml_model.save(coreml_path)
            print(f"✅ CoreML model saved to: {coreml_path}")

            # Get model size
            model_size = os.path.getsize(coreml_path) / (1024 * 1024)  # MB
            print(f"📊 CoreML model size: {model_size:.2f} MB")

            return True

        except ImportError:
            print("⚠️  coremltools not installed. Install with: pip install coremltools")
            return False
        except Exception as e:
            print(f"❌ Error converting to CoreML: {e}")
            return False

def main():
    parser = argparse.ArgumentParser(description='Train SoilVision ML Model')
    parser.add_argument('--data_dir', type=str, required=True,
                       help='Path to dataset directory')
    parser.add_argument('--output_dir', type=str, default='./model_outputs',
                       help='Path to output directory')
    parser.add_argument('--epochs', type=int, default=EPOCHS,
                       help=f'Number of training epochs (default: {EPOCHS})')
    parser.add_argument('--batch_size', type=int, default=BATCH_SIZE,
                       help=f'Batch size (default: {BATCH_SIZE})')

    args = parser.parse_args()

    # Update global variables
    global EPOCHS, BATCH_SIZE
    EPOCHS = args.epochs
    BATCH_SIZE = args.batch_size

    try:
        # Initialize trainer
        trainer = SoilClassifierTrainer(args.data_dir, args.output_dir)

        # Validate dataset
        trainer.validate_dataset()

        # Create data generators
        train_generator, validation_generator = trainer.create_data_generators()

        # Build model
        trainer.build_model()

        # Train model
        trainer.train_model(train_generator, validation_generator)

        # Evaluate model
        evaluation_results = trainer.evaluate_model(validation_generator)

        # Plot training history
        trainer.plot_training_history()

        # Save model and metadata
        trainer.save_model_and_metadata(evaluation_results)

        # Convert to CoreML
        trainer.convert_to_coreml()

        print("\n🎉 Training completed successfully!")
        print(f"📁 All outputs saved to: {args.output_dir}")

    except Exception as e:
        print(f"❌ Training failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()