# SoilVision Dataset Structure

This directory should contain images for training the soil classification model.

## Directory Structure

```
dataset/
├── clay/          # Images of clay soil
├── loam/          # Images of loam soil
├── sandy/         # Images of sandy soil
├── silt/          # Images of silt soil
├── peat/          # Images of peat soil
└── chalk/         # Images of chalk soil
```

## Image Requirements

- **Format**: JPEG, PNG, or BMP
- **Resolution**: Minimum 224x224 pixels (higher is better)
- **Quality**: Clear, well-lit images
- **Content**: Soil samples with minimal background
- **Quantity**: Minimum 500 images per class for good training

## Image Guidelines

### DO include:
- Clear soil texture details
- Various lighting conditions
- Different moisture levels
- Multiple camera angles
- Close-up shots showing soil particles

### AVOID:
- Blurry or out-of-focus images
- Heavy shadows or overexposure
- Non-soil objects dominating the frame
- Text overlays or watermarks
- Very dark or very bright images

## Data Collection Tips

1. **Diversity**: Collect samples from different locations
2. **Consistency**: Try to maintain similar framing across classes
3. **Quality**: Use good lighting and focus
4. **Quantity**: More images generally lead to better models
5. **Balance**: Aim for similar numbers of images per class

## Training

Once you have collected the dataset:

1. Place images in the appropriate class directories
2. Run the training script:
   ```bash
   python3 train_model.py --data_dir ./dataset --output_dir ./model_outputs
   ```
3. Convert to CoreML format:
   ```bash
   python3 convert_to_coreml.py --model_path ./model_outputs/soil_classifier_model.h5
   ```

## Example Image Sources

- Agricultural research databases
- Soil science textbooks and publications
- Field photography (with permission)
- Online soil science resources
- Collaborations with agricultural institutions

Remember to respect copyright and usage rights when collecting training data.