# SoilVision - AI-Powered Soil Classification App

SoilVision is an innovative iOS application that enables farmers, researchers, and agronomists to instantly identify soil types using artificial intelligence. Simply capture or upload a soil image, and the app will classify it as clay, loam, sandy, silt, peat, or chalk with confidence scores.

## 🌟 Features

### Core Functionality
- **Instant Soil Classification**: Classify soil samples into 6 types (clay, loam, sandy, silt, peat, chalk)
- **Camera Integration**: Native iOS camera with real-time preview and guidance
- **Image Processing**: Advanced preprocessing for optimal ML model performance
- **Confidence Scoring**: Detailed confidence metrics and probability breakdowns
- **Offline-First**: Works without internet connection with local SQLite storage
- **Location Tagging**: Optional GPS coordinates for analysis mapping
- **Export & Sharing**: PDF reports, CSV data, and social media sharing

### User Experience
- **Onboarding**: Smooth introduction with optional authentication
- **Guest Mode**: Full functionality without account registration
- **History Tracking**: Complete scan history with search and filter capabilities
- **Modern UI**: Clean, intuitive interface with earth-tone design system
- **Accessibility**: VoiceOver support and high contrast options

## 🏗️ Architecture

### Technology Stack
- **Frontend**: SwiftUI with MVVM architecture
- **Machine Learning**: CoreML with Vision framework
- **Local Storage**: SQLite for offline data persistence
- **Cloud Services**: Firebase Auth and Firestore (optional)
- **Camera**: AVFoundation for native camera integration
- **Location**: CoreLocation for GPS tagging

### Project Structure
```
SoilVision/
├── App/                              # iOS Application
│   ├── SoilVisionApp.swift          # App entry point
│   ├── ContentView.swift            # Root view controller
│   ├── Views/                       # SwiftUI Views
│   │   ├── CameraView.swift         # Camera interface
│   │   ├── ResultView.swift         # Classification results
│   │   ├── HistoryView.swift        # Test history
│   │   ├── ProfileView.swift        # User profile
│   │   └── OnboardingView.swift     # Welcome screens
│   ├── Models/                      # Data Models
│   │   ├── SoilResult.swift         # Soil test result
│   │   ├── User.swift               # User profile
│   │   └── LocationData.swift       # GPS location
│   ├── ViewModels/                  # MVVM View Models
│   │   ├── CameraViewModel.swift    # Camera logic
│   │   ├── ResultViewModel.swift    # Result processing
│   │   ├── HistoryViewModel.swift   # History management
│   │   └── ProfileViewModel.swift   # User profile logic
│   ├── Services/                    # Business Logic
│   │   ├── AuthManager.swift        # Firebase authentication
│   │   ├── DatabaseManager.swift    # SQLite operations
│   │   ├── SoilClassifierService.swift  # ML inference
│   │   ├── ImageProcessor.swift     # Image preprocessing
│   │   ├── LocationManager.swift    # GPS services
│   │   ├── SyncManager.swift        # Cloud sync
│   │   └── ReportExporter.swift     # Export functionality
│   ├── Utils/                       # Helper Utilities
│   │   ├── Extensions.swift         # Swift extensions
│   │   ├── Constants.swift          # App constants
│   │   └── Validators.swift         # Input validation
│   ├── Resources/                   # External Resources
│   │   └── SoilClassifier.mlmodel   # Trained ML model
│   └── SoilVision.xcodeproj         # Xcode project file
├── ML_Model/                        # Machine Learning Components
│   ├── train_model.py              # Training script
│   ├── convert_to_coreml.py        # Model conversion
│   ├── dataset/                    # Training images
│   │   ├── clay/                   # Clay soil images
│   │   ├── loam/                   # Loam soil images
│   │   ├── sandy/                  # Sandy soil images
│   │   ├── silt/                   # Silt soil images
│   │   ├── peat/                   # Peat soil images
│   │   └── chalk/                  # Chalk soil images
│   └── model_outputs/              # Trained models
└── Documentation/                   # Project documentation
```

## 🚀 Getting Started

### Prerequisites
- **Xcode 15+** with iOS 16.0+ SDK
- **Swift 5.8+**
- **Physical iOS device** (for camera testing)
- **Python 3.8+** (for ML model training)
- **TensorFlow 2.x** (for model training)
- **coremltools** (for model conversion)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/soilvision.git
   cd soilvision
   ```

2. **Open in Xcode**
   ```bash
   open SoilVision/App/SoilVision.xcodeproj
   ```

3. **Configure Firebase (Optional)**
   - Create a Firebase project at https://console.firebase.google.com
   - Download `GoogleService-Info.plist` and add to the project
   - Enable Authentication and Firestore services

4. **Build and Run**
   - Select your physical device (camera required)
   - Press `Cmd+R` to build and run the app

### ML Model Training (Optional)

If you want to train your own soil classification model:

1. **Prepare Dataset**
   ```bash
   mkdir -p ML_Model/dataset/{clay,loam,sandy,silt,peat,chalk}
   # Add at least 500 images per class
   ```

2. **Install Python Dependencies**
   ```bash
   pip install tensorflow opencv-python numpy matplotlib scikit-learn
   pip install coremltools  # For iOS conversion
   ```

3. **Train Model**
   ```bash
   cd ML_Model
   python3 train_model.py --data_dir ./dataset --output_dir ./model_outputs
   ```

4. **Convert to CoreML**
   ```bash
   python3 convert_to_coreml.py --model_path ./model_outputs/soil_classifier_model.h5
   ```

5. **Add to iOS Project**
   - Copy `SoilClassifier.mlmodel` to `App/Resources/`
   - Add to Xcode project target

## 📱 Usage Guide

### First Launch
1. **Onboarding**: Swipe through introduction screens
2. **Authentication**: Choose guest mode or create an account
3. **Permissions**: Grant camera and optional location permissions

### Analyzing Soil
1. **Capture Photo**: Use the built-in camera or select from gallery
2. **Position Sample**: Center soil in the camera frame
3. **Review & Analyze**: Confirm image and tap "Analyze Soil"
4. **View Results**: See classification with confidence scores
5. **Save or Share**: Save to history or export results

## 🤖 Machine Learning

### Model Architecture
```
Input (224x224x3)
├── Conv2D(32, 3x3, ReLU) + BatchNorm
├── Conv2D(32, 3x3, ReLU) + BatchNorm
├── MaxPooling2D + Dropout(0.25)
├── Conv2D(64, 3x3, ReLU) + BatchNorm
├── Conv2D(64, 3x3, ReLU) + BatchNorm
├── MaxPooling2D + Dropout(0.25)
├── Conv2D(128, 3x3, ReLU) + BatchNorm
├── Conv2D(128, 3x3, ReLU) + BatchNorm
├── MaxPooling2D + Dropout(0.25)
├── Conv2D(256, 3x3, ReLU) + BatchNorm
├── Conv2D(256, 3x3, ReLU) + BatchNorm
├── MaxPooling2D + Dropout(0.25)
├── Flatten
├── Dense(512, ReLU) + BatchNorm + Dropout(0.5)
├── Dense(256, ReLU) + BatchNorm + Dropout(0.4)
└── Dense(6, Softmax)
```

### Training Parameters
- **Optimizer**: Adam (lr=0.001)
- **Loss**: Categorical Crossentropy
- **Metrics**: Accuracy, Top-K Accuracy
- **Batch Size**: 32
- **Epochs**: 50 (with early stopping)
- **Data Augmentation**: Rotation, zoom, brightness, contrast

## 🔧 Configuration

### App Settings
Edit `SoilVision/App/Utils/Constants.swift` for custom configuration:

```swift
struct AppConstants {
    static let appName = "SoilVision"
    static let appVersion = "1.0"

    struct ML {
        static let confidenceThreshold: Double = 0.6
        static let imageSize = CGSize(width: 224, height: 224)
    }
}
```

## 🧪 Testing

### Unit Tests
```bash
# Run unit tests
xcodebuild test -scheme SoilVision -destination 'platform=iOS Simulator,name=iPhone 14'
```

### UI Tests
- Camera functionality (requires physical device)
- Navigation and user flows
- Accessibility testing

## 📊 Performance

### Benchmarks
- **App Launch**: <3 seconds
- **Camera Capture**: <500ms latency
- **Image Processing**: <1 second
- **ML Inference**: <2 seconds
- **Memory Usage**: <150MB peak

## 🔒 Security & Privacy

### Data Protection
- **On-device Processing**: All ML inference happens locally
- **Local Encryption**: SQLite database encryption
- **No Tracking**: No analytics or tracking
- **Privacy by Design**: Minimal data collection

## 📄 License

This project is licensed under the MIT License.

---

**SoilVision** - Making soil science accessible to everyone, one photo at a time. 🌱