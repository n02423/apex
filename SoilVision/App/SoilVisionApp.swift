import SwiftUI
import FirebaseCore

@main
struct SoilVisionApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var databaseManager = DatabaseManager()
    @StateObject private var locationManager = LocationManager()

    init() {
        // Configure Firebase when app launches
        FirebaseApp.configure()

        // Configure appearance
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(databaseManager)
                .environmentObject(locationManager)
                .onAppear {
                    setupApp()
                }
        }
    }

    private func setupApp() {
        // Initialize services
        authManager.checkAuthState()
        locationManager.requestPermission()

        // Initialize database
        databaseManager.setupDatabase()

        print("SoilVision app initialized")
    }

    private func configureAppearance() {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(Color.AppTheme.primaryBrown)
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.AppTheme.backgroundCream)]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.AppTheme.backgroundCream)]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Color.AppTheme.primaryBrown)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.AppTheme.accentGreen)]
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.AppTheme.backgroundCream)]

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Configure status bar
        UIApplication.shared.statusBarStyle = .lightContent
    }
}

// MARK: - App Theme Extension
extension Color {
    struct AppTheme {
        static let primaryBrown = Color(red: 0.553, green: 0.432, blue: 0.388) // #8D6E63
        static let secondaryBeige = Color(red: 0.843, green: 0.8, blue: 0.784) // #D7CCC8
        static let accentGreen = Color(red: 0.408, green: 0.624, blue: 0.219) // #689F38
        static let backgroundCream = Color(red: 1.0, green: 0.973, blue: 0.882) // #FFF8E1
        static let textDarkBrown = Color(red: 0.306, green: 0.204, blue: 0.18) // #4E342E
        static let errorRed = Color(red: 0.827, green: 0.184, blue: 0.184) // #D32F2F
        static let successGreen = Color(red: 0.224, green: 0.557, blue: 0.235) // #388E3C
    }
}

// MARK: - App Constants
struct AppConstants {
    static let appName = "SoilVision"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    struct URLs {
        static let privacyPolicy = "https://soilvision.app/privacy"
        static let termsOfService = "https://soilvision.app/terms"
        static let support = "https://soilvision.app/support"
        static let about = "https://soilvision.app/about"
    }

    struct Storage {
        static let maxImageSize: Int64 = 5 * 1024 * 1024 // 5MB
        static let maxLocalResults = 100
        static let imageCompressionQuality: CGFloat = 0.8
    }

    struct ML {
        static let confidenceThreshold: Double = 0.6
        static let imageSize = CGSize(width: 224, height: 224)
        static let maxInferenceTime: TimeInterval = 5.0
    }

    struct Location {
        static let desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
        static let distanceFilter: CLLocationDistance = 10.0
        static let timeout: TimeInterval = 10.0
    }

    struct UI {
        static let animationDuration: TimeInterval = 0.3
        static let hapticFeedbackIntensity: CGFloat = 0.7
        static let cornerRadius: CGFloat = 12.0
        static let shadowRadius: CGFloat = 4.0
        static let shadowOpacity: Double = 0.15
    }
}