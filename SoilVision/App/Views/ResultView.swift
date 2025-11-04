import SwiftUI

struct ResultView: View {
    let capturedImage: UIImage
    let onClose: () -> Void
    @StateObject private var viewModel = ResultViewModel()
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var databaseManager: DatabaseManager

    var body: some View {
        NavigationView {
            ZStack {
                Color.AppTheme.backgroundCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header with image
                        ResultHeaderView(image: capturedImage)

                        if viewModel.isAnalyzing {
                            AnalyzingView()
                        } else if let result = viewModel.classificationResult {
                            // Classification results
                            ClassificationResultView(result: result)

                            // Detailed probabilities
                            ProbabilityBreakdownView(result: result)

                            // Location information (if available)
                            if let location = viewModel.locationData {
                                LocationInfoView(location: location)
                            }

                            // Action buttons
                            ActionButtonsView(
                                onSave: { viewModel.saveResult() },
                                onShare: { viewModel.shareResult() },
                                onRetake: onClose
                            )
                        } else if let error = viewModel.errorMessage {
                            ErrorView(error: error, onRetry: {
                                viewModel.analyzeImage(capturedImage)
                            })
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Analysis Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onClose()
                    }
                }
            }
            .onAppear {
                viewModel.analyzeImage(capturedImage)
            }
            .sheet(isPresented: $viewModel.showShareSheet) {
                if let result = viewModel.savedResult {
                    ShareSheet(items: [result])
                }
            }
            .alert("Success", isPresented: $viewModel.showSaveAlert) {
                Button("OK") { }
            } message: {
                Text(viewModel.saveMessage)
            }
        }
    }
}

struct ResultHeaderView: View {
    let image: UIImage

    var body: some View {
        VStack(spacing: 16) {
            // Captured image
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .cornerRadius(12)
                .shadow(radius: 5)

            // Image quality indicator
            ImageQualityIndicator(image: image)
        }
    }
}

struct ImageQualityIndicator: View {
    let image: UIImage
    @State private var qualityAnalysis: ImageQualityAnalysis?

    var body: some View {
        if let analysis = qualityAnalysis {
            HStack {
                Image(systemName: analysis.isAcceptable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(analysis.isAcceptable ? .AppTheme.successGreen : .AppTheme.errorRed)

                Text(analysis.isAcceptable ? "Good image quality" : "Image quality could be improved")
                    .font(.caption)
                    .foregroundColor(.AppTheme.textDarkBrown.opacity(0.8))

                Spacer()

                Text("\(Int(analysis.qualityScore))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.AppTheme.textDarkBrown.opacity(0.6))
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.AppTheme.secondaryBeige.opacity(0.3))
            .cornerRadius(8)
        }
        .onAppear {
            qualityAnalysis = ImageProcessor.shared.analyzeImageQuality(image)
        }
    }
}

struct AnalyzingView: View {
    @State private var animationPhase = 0

    var body: some View {
        VStack(spacing: 20) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(Color.AppTheme.primaryBrown.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundColor(.AppTheme.primaryBrown)
                    .scaleEffect(1.0 + 0.1 * sin(animationPhase))
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: animationPhase
                    )
            }

            VStack(spacing: 8) {
                Text("Analyzing Soil Sample")
                    .font(.headline)
                    .foregroundColor(.AppTheme.textDarkBrown)

                Text("Our AI is identifying the soil type...")
                    .font(.caption)
                    .foregroundColor(.AppTheme.textDarkBrown.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            // Progress indicator
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .AppTheme.accentGreen))
                .scaleEffect(1.2)

            // Analysis steps
            VStack(alignment: .leading, spacing: 8) {
                AnalysisStep(text: "Processing image", isComplete: true)
                AnalysisStep(text: "Extracting features", isComplete: true)
                AnalysisStep(text: "Classifying soil type", isComplete: animationPhase > 1)
                AnalysisStep(text: "Calculating confidence", isComplete: animationPhase > 2)
            }
            .padding()
        }
        .onAppear {
            withAnimation {
                animationPhase = 3
            }
        }
    }
}

struct AnalysisStep: View {
    let text: String
    let isComplete: Bool

    var body: some View {
        HStack {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isComplete ? .AppTheme.successGreen : .AppTheme.secondaryBeige)
                .animation(.easeInOut(duration: 0.3), value: isComplete)

            Text(text)
                .font(.caption)
                .foregroundColor(isComplete ? .AppTheme.textDarkBrown : .AppTheme.textDarkBrown.opacity(0.5))

            Spacer()
        }
    }
}

struct ClassificationResultView: View {
    let result: SoilClassificationResult

    var body: some View {
        VStack(spacing: 16) {
            // Main result
            VStack(spacing: 8) {
                Text("Soil Type Identified")
                    .font(.caption)
                    .foregroundColor(.AppTheme.textDarkBrown.opacity(0.7))
                    .textCase(.uppercase)

                Text(result.primarySoilType.rawValue)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.AppTheme.primaryBrown)

                Text("\(result.confidencePercentage)% Confidence")
                    .font(.title3)
                    .foregroundColor(.AppTheme.textDarkBrown.opacity(0.8))
            }

            // Confidence meter
            ConfidenceMeterView(
                confidence: result.confidence,
                level: result.confidenceLevel,
                color: confidenceColor(for: result.confidence)
            )

            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("About \(result.primarySoilType.rawValue) Soil")
                    .font(.headline)
                    .foregroundColor(.AppTheme.textDarkBrown)

                Text(result.primarySoilType.description)
                    .font(.body)
                    .foregroundColor(.AppTheme.textDarkBrown.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.AppTheme.secondaryBeige.opacity(0.3))
            .cornerRadius(12)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 5)
    }

    private func confidenceColor(for confidence: Float) -> Color {
        switch confidence {
        case 0.8...1.0:
            return .AppTheme.successGreen
        case 0.6..<0.8:
            return .AppTheme.accentGreen
        case 0.4..<0.6:
            return .orange
        default:
            return .AppTheme.errorRed
        }
    }
}

struct ConfidenceMeterView: View {
    let confidence: Float
    let level: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.AppTheme.secondaryBeige.opacity(0.3))
                        .frame(height: 20)

                    // Progress
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(confidence), height: 20)
                        .animation(.easeInOut(duration: 1.0), value: confidence)
                }
            }
            .frame(height: 20)

            // Label
            HStack {
                Text("Confidence Level: \(level)")
                    .font(.caption)
                    .foregroundColor(.AppTheme.textDarkBrown.opacity(0.7))

                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

struct ProbabilityBreakdownView: View {
    let result: SoilClassificationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Probabilities")
                .font(.headline)
                .foregroundColor(.AppTheme.textDarkBrown)

            ForEach(result.allProbabilities, id: \.soilType) { probability in
                ProbabilityRowView(
                    soilType: probability.soilType,
                    percentage: probability.percentage,
                    confidence: probability.confidence,
                    isTopResult: probability.soilType == result.primarySoilType
                )
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 3)
    }
}

struct ProbabilityRowView: View {
    let soilType: SoilType
    let percentage: Int
    let confidence: Float
    let isTopResult: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                // Soil type with icon
                HStack(spacing: 8) {
                    Image(systemName: soilType.icon)
                        .foregroundColor(soilType.color)
                        .frame(width: 20)

                    Text(soilType.rawValue)
                        .font(isTopResult ? .headline : .body)
                        .foregroundColor(.AppTheme.textDarkBrown)
                }

                Spacer()

                // Percentage
                Text("\(percentage)%")
                    .font(isTopResult ? .headline : .body)
                    .fontWeight(isTopResult ? .bold : .medium)
                    .foregroundColor(.AppTheme.textDarkBrown)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.AppTheme.secondaryBeige.opacity(0.2))
                        .frame(height: isTopResult ? 12 : 8)

                    // Progress
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isTopResult ? soilType.color : soilType.color.opacity(0.7))
                        .frame(width: geometry.size.width * CGFloat(confidence), height: isTopResult ? 12 : 8)
                        .animation(.easeInOut(duration: 1.0), value: confidence)
                }
            }
            .frame(height: isTopResult ? 12 : 8)
        }
        .padding(.vertical, 4)
    }
}

struct LocationInfoView: View {
    let location: LocationData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.AppTheme.accentGreen)

                Text("Location Data")
                    .font(.headline)
                    .foregroundColor(.AppTheme.textDarkBrown)

                Spacer()

                Text(location.accuracyDescription)
                    .font(.caption)
                    .foregroundColor(.AppTheme.textDarkBrown.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Coordinates: \(location.formattedCoordinates)")
                    .font(.body)
                    .foregroundColor(.AppTheme.textDarkBrown.opacity(0.8))

                Text("Captured: \(location.formattedDate)")
                    .font(.caption)
                    .foregroundColor(.AppTheme.textDarkBrown.opacity(0.6))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 3)
    }
}

struct ActionButtonsView: View {
    let onSave: () -> Void
    let onShare: () -> Void
    let onRetake: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button("Save Result") {
                onSave()
            }
            .buttonStyle(PrimaryButtonStyle())

            HStack(spacing: 12) {
                Button("Share") {
                    onShare()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Retake Photo") {
                    onRetake()
                }
                .foregroundColor(.AppTheme.textDarkBrown)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.AppTheme.secondaryBeige.opacity(0.5))
                .cornerRadius(12)
            }
        }
        .padding(.top, 20)
    }
}

struct ErrorView: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.AppTheme.errorRed)

            Text("Analysis Failed")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.AppTheme.textDarkBrown)

            Text(error)
                .font(.body)
                .foregroundColor(.AppTheme.textDarkBrown.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }
}

#Preview {
    ResultView(capturedImage: UIImage(systemName: "photo")!) {
        print("Close result view")
    }
    .environmentObject(AuthManager())
    .environmentObject(LocationManager())
    .environmentObject(DatabaseManager())
}