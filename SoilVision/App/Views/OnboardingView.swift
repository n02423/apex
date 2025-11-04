import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @EnvironmentObject var authManager: AuthManager
    let onComplete: () -> Void

    private let pages = [
        OnboardingPageData(
            title: "Welcome to SoilVision",
            subtitle: "Discover your soil type instantly with AI-powered analysis",
            imageName: "leaf.fill",
            backgroundColor: Color.AppTheme.backgroundCream
        ),
        OnboardingPageData(
            title: "Capture or Upload",
            subtitle: "Take a photo of soil or choose from your gallery to analyze its composition",
            imageName: "camera.fill",
            backgroundColor: Color.AppTheme.backgroundCream
        ),
        OnboardingPageData(
            title: "Instant Classification",
            subtitle: "Get immediate results identifying soil types like clay, loam, sandy, silt, peat, or chalk",
            imageName: "brain.head.profile",
            backgroundColor: Color.AppTheme.backgroundCream
        ),
        OnboardingPageData(
            title: "Track Your Analysis",
            subtitle: "Build a history of your soil tests with location data and confidence scores",
            imageName: "chart.bar.fill",
            backgroundColor: Color.AppTheme.backgroundCream
        ),
        OnboardingPageData(
            title: "Choose Your Experience",
            subtitle: "Use the app anonymously or create an account to sync across devices",
            imageName: "person.2.fill",
            backgroundColor: Color.AppTheme.backgroundCream
        )
    ]

    var body: some View {
        VStack {
            // Progress indicator
            HStack {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentPage ? Color.AppTheme.accentGreen : Color.AppTheme.secondaryBeige)
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentPage ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            .padding(.top, 20)

            // TabView with pages
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPage(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Bottom buttons
            VStack(spacing: 16) {
                if currentPage == pages.count - 1 {
                    // Final page - Show auth options
                    AuthOptionsView(onComplete: onComplete)
                } else {
                    // Next/Skip buttons
                    HStack(spacing: 16) {
                        // Skip button
                        Button("Skip") {
                            onComplete()
                        }
                        .foregroundColor(.AppTheme.textDarkBrown.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)

                        // Next button
                        Button("Next") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if currentPage < pages.count - 1 {
                                    currentPage += 1
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 40)
        }
        .background(pages[currentPage].backgroundColor)
        .ignoresSafeArea()
        .onAppear {
            // Setup for smooth animations
            UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(Color.AppTheme.accentGreen)
            UIPageControl.appearance().pageIndicatorTintColor = UIColor(Color.AppTheme.secondaryBeige)
        }
    }
}

struct OnboardingPageData {
    let title: String
    let subtitle: String
    let imageName: String
    let backgroundColor: Color
}

struct OnboardingPage: View {
    let page: OnboardingPageData

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.AppTheme.primaryBrown.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: page.imageName)
                    .font(.system(size: 50))
                    .foregroundColor(.AppTheme.primaryBrown)
            }

            // Title and subtitle
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.AppTheme.textDarkBrown)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.title3)
                    .foregroundColor(.AppTheme.textDarkBrown.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineLimit(3)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

struct AuthOptionsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showSignUp = false
    @State private var showSignIn = false
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Anonymous option
            VStack(spacing: 12) {
                Text("Continue as Guest")
                    .font(.headline)
                    .foregroundColor(.AppTheme.textDarkBrown)

                Text("Use all features without creating an account")
                    .font(.caption)
                    .foregroundColor(.AppTheme.textDarkBrown.opacity(0.6))
                    .multilineTextAlignment(.center)

                Button("Start as Guest") {
                    onComplete()
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Divider()
                .background(Color.AppTheme.secondaryBeige)

            // Account option
            VStack(spacing: 12) {
                Text("Create Account")
                    .font(.headline)
                    .foregroundColor(.AppTheme.textDarkBrown)

                Text("Sync data across devices and save your progress")
                    .font(.caption)
                    .foregroundColor(.AppTheme.textDarkBrown.opacity(0.6))
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button("Sign Up") {
                        showSignUp = true
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Sign In") {
                        showSignIn = true
                    }
                    .foregroundColor(.AppTheme.accentGreen)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.AppTheme.accentGreen.opacity(0.1))
                    .cornerRadius(AppConstants.UI.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                            .stroke(Color.AppTheme.accentGreen, lineWidth: 2)
                    )
                }
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showSignUp) {
            SignUpView(isPresented: $showSignUp, onComplete: onComplete)
        }
        .sheet(isPresented: $showSignIn) {
            SignInView(isPresented: $showSignIn, onComplete: onComplete)
        }
    }
}

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @Binding var isPresented: Bool
    let onComplete: () -> Void

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        User.validateEmail(email) &&
        password.count >= 6 &&
        password == confirmPassword
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.headline)
                        .foregroundColor(.AppTheme.textDarkBrown)

                    TextField("Enter your name", text: $name)
                        .textFieldStyle(RoundedTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.headline)
                        .foregroundColor(.AppTheme.textDarkBrown)

                    TextField("Enter your email", text: $email)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.headline)
                        .foregroundColor(.AppTheme.textDarkBrown)

                    HStack {
                        if showPassword {
                            TextField("Enter password", text: $password)
                        } else {
                            SecureField("Enter password", text: $password)
                        }

                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.AppTheme.textDarkBrown.opacity(0.6))
                        }
                    }
                    .textFieldStyle(RoundedTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.headline)
                        .foregroundColor(.AppTheme.textDarkBrown)

                    HStack {
                        if showConfirmPassword {
                            TextField("Confirm password", text: $confirmPassword)
                        } else {
                            SecureField("Confirm password", text: $confirmPassword)
                        }

                        Button(action: { showConfirmPassword.toggle() }) {
                            Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                .foregroundColor(.AppTheme.textDarkBrown.opacity(0.6))
                        }
                    }
                    .textFieldStyle(RoundedTextFieldStyle())
                }

                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.AppTheme.errorRed)
                        .padding(.horizontal)
                }

                Spacer()

                Button("Create Account") {
                    authManager.signUp(name: name, email: email, password: password)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isFormValid || authManager.isLoading)
                .opacity(isFormValid && !authManager.isLoading ? 1.0 : 0.6)
            }
            .padding()
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                isPresented = false
                onComplete()
            }
        }
    }
}

struct SignInView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @Binding var isPresented: Bool
    let onComplete: () -> Void

    private var isFormValid: Bool {
        User.validateEmail(email) && !password.isEmpty
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.headline)
                        .foregroundColor(.AppTheme.textDarkBrown)

                    TextField("Enter your email", text: $email)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.headline)
                        .foregroundColor(.AppTheme.textDarkBrown)

                    HStack {
                        if showPassword {
                            TextField("Enter password", text: $password)
                        } else {
                            SecureField("Enter password", text: $password)
                        }

                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.AppTheme.textDarkBrown.opacity(0.6))
                        }
                    }
                    .textFieldStyle(RoundedTextFieldStyle())
                }

                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.AppTheme.errorRed)
                        .padding(.horizontal)
                }

                Button("Forgot Password?") {
                    authManager.resetPassword(email: email)
                }
                .foregroundColor(.AppTheme.accentGreen)
                .font(.caption)

                Spacer()

                Button("Sign In") {
                    authManager.signIn(email: email, password: password)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isFormValid || authManager.isLoading)
                .opacity(isFormValid && !authManager.isLoading ? 1.0 : 0.6)
            }
            .padding()
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                isPresented = false
                onComplete()
            }
        }
    }
}

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.AppTheme.secondaryBeige.opacity(0.3))
            .cornerRadius(AppConstants.UI.cornerRadius)
    }
}

#Preview {
    OnboardingView {
        print("Onboarding completed")
    }
    .environmentObject(AuthManager())
}