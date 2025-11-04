#!/usr/bin/env python3
"""
CoreML Model Conversion Script

This script converts a trained TensorFlow/Keras model to CoreML format
for use in iOS applications with SoilVision.

Usage:
    python convert_to_coreml.py --model_path ./model_outputs/soil_classifier_model.h5
"""

import os
import sys
import argparse
import coremltools as ct
import tensorflow as tf
from tensorflow.keras.models import load_model
import json
from datetime import datetime

def convert_to_coreml(model_path, output_path=None, class_labels=None):
    """
    Convert a trained Keras model to CoreML format

    Args:
        model_path: Path to the trained .h5 model file
        output_path: Output path for the .mlmodel file
        class_labels: List of class labels (soil types)

    Returns:
        Path to the converted CoreML model
    """

    if class_labels is None:
        class_labels = ['clay', 'loam', 'sandy', 'silt', 'peat', 'chalk']

    if output_path is None:
        output_path = model_path.replace('.h5', '.mlmodel')

    print(f"🔄 Converting {model_path} to CoreML format...")

    try:
        # Load the trained model
        model = load_model(model_path)
        print(f"✅ Model loaded successfully")

        # Get model input shape
        input_shape = model.input_shape
        print(f"📐 Model input shape: {input_shape}")

        # Configure classifier
        classifier_config = ct.ClassifierConfig(class_labels=class_labels)

        # Convert model
        # For image models, specify the input type
        if len(input_shape) == 4 and input_shape[1] >= 224:
            # Image input (batch, height, width, channels)
            image_size = (input_shape[2], input_shape[1])  # (width, height)

            coreml_model = ct.convert(
                model,
                inputs=[ct.ImageType(
                    name="input",
                    shape=image_size + (input_shape[3],),
                    scale=1/255.0,  # Normalize if needed
                    bias=[0, 0, 0]   # RGB bias
                )],
                classifier_config=classifier_config,
                convert_to="mlprogram"  # Use modern ML Program format
            )
        else:
            # General input
            coreml_model = ct.convert(
                model,
                classifier_config=classifier_config,
                convert_to="mlprogram"
            )

        # Set model metadata
        coreml_model.short_description = "Soil type classification model for SoilVision iOS app"
        coreml_model.author = "SoilVision Team"
        coreml_model.license = "MIT"
        coreml_model.version = "1.0.0"
        coreml_model.metadata = {
            "created_date": datetime.now().isoformat(),
            "framework": "TensorFlow/Keras",
            "soil_types": class_labels,
            "input_shape": input_shape
        }

        # Add feature descriptions
        coreml_model.input_description["input"] = "RGB image of soil sample"
        coreml_model.output_description["classLabel"] = "Predicted soil type"
        coreml_model.output_description["classProbability"] = "Probability distribution over soil types"

        # Save the CoreML model
        coreml_model.save(output_path)
        print(f"✅ CoreML model saved to: {output_path}")

        # Get model size
        model_size = os.path.getsize(output_path) / (1024 * 1024)  # MB
        print(f"📊 CoreML model size: {model_size:.2f} MB")

        # Test the model
        test_coreml_model(output_path, class_labels)

        return output_path

    except Exception as e:
        print(f"❌ Error converting model: {e}")
        return None

def test_coreml_model(model_path, class_labels):
    """Test the converted CoreML model"""
    print("\n🧪 Testing CoreML model...")

    try:
        import coremltools as ct

        # Load the CoreML model
        model = ct.models.MLModel(model_path)

        # Get model metadata
        metadata = model.metadata
        print(f"📝 Model description: {metadata.get('shortDescription', 'No description')}")
        print(f"👤 Author: {metadata.get('author', 'Unknown')}")
        print(f"📋 Version: {metadata.get('version', 'Unknown')}")

        # Get input/output descriptions
        input_desc = model.input_description
        output_desc = model.output_description

        print(f"\n📥 Inputs:")
        for name, desc in input_desc.items():
            print(f"  - {name}: {desc}")

        print(f"\n📤 Outputs:")
        for name, desc in output_desc.items():
            print(f"  - {name}: {desc}")

        print("✅ CoreML model test completed successfully")

    except Exception as e:
        print(f"⚠️  Error testing CoreML model: {e}")

def create_sample_model():
    """Create a simple sample model for testing"""
    print("🏗️  Creating sample model for testing...")

    from tensorflow.keras.models import Sequential
    from tensorflow.keras.layers import Conv2D, MaxPooling2D, Flatten, Dense, Dropout

    model = Sequential([
        Conv2D(32, (3, 3), activation='relu', input_shape=(224, 224, 3)),
        MaxPooling2D(2, 2),
        Conv2D(64, (3, 3), activation='relu'),
        MaxPooling2D(2, 2),
        Flatten(),
        Dense(128, activation='relu'),
        Dropout(0.5),
        Dense(6, activation='softmax')  # 6 soil types
    ])

    model.compile(
        optimizer='adam',
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )

    # Save the sample model
    sample_path = './sample_soil_model.h5'
    model.save(sample_path)
    print(f"✅ Sample model saved to: {sample_path}")

    return sample_path

def main():
    parser = argparse.ArgumentParser(description='Convert SoilVision model to CoreML')
    parser.add_argument('--model_path', type=str,
                       help='Path to trained Keras model (.h5 file)')
    parser.add_argument('--output_path', type=str,
                       help='Output path for CoreML model (.mlmodel file)')
    parser.add_argument('--create_sample', action='store_true',
                       help='Create a sample model for testing')
    parser.add_argument('--class_labels', nargs='+',
                       default=['clay', 'loam', 'sandy', 'silt', 'peat', 'chalk'],
                       help='Class labels for classification')

    args = parser.parse_args()

    if args.create_sample:
        # Create and convert sample model
        sample_path = create_sample_model()
        convert_to_coreml(sample_path, output_path="SampleSoilClassifier.mlmodel",
                         class_labels=args.class_labels)
    elif args.model_path:
        # Convert existing model
        if not os.path.exists(args.model_path):
            print(f"❌ Model file not found: {args.model_path}")
            sys.exit(1)

        convert_to_coreml(args.model_path, args.output_path, args.class_labels)
    else:
        print("❌ Please provide --model_path or use --create_sample")
        parser.print_help()
        sys.exit(1)

if __name__ == "__main__":
    main()