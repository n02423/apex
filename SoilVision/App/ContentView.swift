import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showOnboarding = false
    @State private var hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

    var body: some View {
        Group {
            if authManager.isLoading {
                LoadingView()
            } else if !hasSeenOnboarding {
                OnboardingView {
                    hasSeenOnboarding = true
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                }
            } else if authManager.isAnonymous {
                MainTabView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
        .animation(.easeInOut, value: hasSeenOnboarding)
    }
}

struct LoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color.AppTheme.backgroundCream
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // App Logo/Icon
                ZStack {
                    Circle()
                        .fill(Color.AppTheme.primaryBrown)
                        .frame(width: 120, height: 120)
                        .shadow(radius: 10)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.AppTheme.backgroundCream)
                        .rotationEffect(.degrees(isAnimating ? 10 : -10))
                        .animation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }

                // App Name
                Text("SoilVision")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.AppTheme.textDarkBrown)

                // Tagline
                Text("Discover Your Soil Type")
                    .font(.title3)
                    .foregroundColor(.AppTheme.textDarkBrown.opacity(0.8))

                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .AppTheme.accentGreen))
                    .scaleEffect(1.2)

                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.AppTheme.textDarkBrown.opacity(0.6))
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Camera Tab
            CameraView()
                .tabItem {
                    Label("Camera", systemImage: "camera.fill")
                }
                .tag(0)

            // History Tab
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(1)

            // Map Tab (if location services are enabled)
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(2)

            // Profile Tab
            ProfileView()
                .tabItem {
                    Label(
                        authManager.isAnonymous ? "Guest" : "Profile",
                        systemImage: "person.fill"
                    )
                }
                .tag(3)
        }
        .accentColor(.AppTheme.accentGreen)
        .onAppear {
            // Customize tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.AppTheme.primaryBrown)

            // Set tab bar item colors
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.AppTheme.accentGreen)]
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.AppTheme.backgroundCream)]
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.AppTheme.accentGreen)
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.AppTheme.backgroundCream)

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// Placeholder MapView (will be implemented later)
struct MapView: View {
    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        NavigationView {
            VStack {
                if locationManager.authorizationStatus == .denied {
                    LocationDeniedView()
                } else if locationManager.authorizationStatus == .notDetermined {
                    LocationPermissionView()
                } else {
                    Text("Map View")
                        .font(.title2)
                        .foregroundColor(.AppTheme.textDarkBrown)
                        .padding()

                    Text("Map functionality will be implemented in a future update.")
                        .font(.body)
                        .foregroundColor(.AppTheme.textDarkBrown.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding()

                    Spacer()

                    if let location = locationManager.currentLocation {
                        VStack {
                            Text("Current Location:")
                                .font(.headline)
                                .foregroundColor(.AppTheme.textDarkBrown)

                            Text(location.formattedCoordinates)
                                .font(.monospaced(.body)())
                                .foregroundColor(.AppTheme.textDarkBrown.opacity(0.8))
                                .padding(.horizontal)

                            Text("Accuracy: \(location.accuracyDescription)")
                                .font(.caption)
                                .foregroundColor(.AppTheme.textDarkBrown.opacity(0.6))
                        }
                        .padding()
                        .background(Color.AppTheme.secondaryBeige.opacity(0.3))
                        .cornerRadius(AppConstants.UI.cornerRadius)
                        .padding(.horizontal)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct LocationDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash")
                .font(.system(size: 60))
                .foregroundColor(.AppTheme.errorRed)

            Text("Location Access Denied")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.AppTheme.textDarkBrown)

            Text("To see your soil analysis locations on the map, please enable location services in Settings.")
                .font(.body)
                .foregroundColor(.AppTheme.textDarkBrown.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }
}

struct LocationPermissionView: View {
    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location")
                .font(.system(size: 60))
                .foregroundColor(.AppTheme.accentGreen)

            Text("Enable Location Services")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.AppTheme.textDarkBrown)

            Text("Allow location access to see where you've taken soil samples and analyze patterns by location.")
                .font(.body)
                .foregroundColor(.AppTheme.textDarkBrown.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Enable Location") {
                locationManager.requestPermission()
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Not Now") {
                // User can continue without location
            }
            .foregroundColor(.AppTheme.textDarkBrown.opacity(0.6))
        }
        .padding()
    }
}

// MARK: - Custom Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.AppTheme.backgroundCream)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.AppTheme.accentGreen)
            .cornerRadius(AppConstants.UI.cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.AppTheme.accentGreen)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.AppTheme.accentGreen.opacity(0.1))
            .cornerRadius(AppConstants.UI.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                    .stroke(Color.AppTheme.accentGreen, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .environmentObject(DatabaseManager())
        .environmentObject(LocationManager())
}