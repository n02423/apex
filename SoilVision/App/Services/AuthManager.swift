import Foundation
import FirebaseAuth
import Combine

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isAnonymous = true
    @Published var currentUser: User?
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Set up authentication state listener
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.handleAuthStateChange(user)
            }
        }
    }

    func checkAuthState() {
        isLoading = false
        // Start with anonymous user for demo
        currentUser = User.createAnonymousUser()
        isAnonymous = true
        isAuthenticated = false
    }

    private func handleAuthStateChange(_ user: FirebaseAuth.User?) {
        isLoading = false

        if let firebaseUser = user {
            if firebaseUser.isAnonymous {
                // Anonymous user
                currentUser = User.createAnonymousUser()
                isAnonymous = true
                isAuthenticated = false
            } else {
                // Authenticated user
                currentUser = User(
                    id: firebaseUser.uid,
                    name: firebaseUser.displayName ?? "",
                    email: firebaseUser.email ?? ""
                )
                isAnonymous = false
                isAuthenticated = true
            }
        } else {
            // No user, create anonymous
            signInAnonymously()
        }
    }

    func signInAnonymously() {
        Auth.auth().signInAnonymously { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("Anonymous sign-in error: \(error.localizedDescription)")
                } else {
                    print("Anonymous sign-in successful")
                    self?.isAnonymous = true
                    self?.isAuthenticated = false
                    self?.currentUser = User.createAnonymousUser()
                }
            }
        }
    }

    func signUp(name: String, email: String, password: String) {
        isLoading = true
        errorMessage = nil

        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                guard let result = result else {
                    self?.errorMessage = "Unknown error occurred"
                    return
                }

                // Update user profile
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = name
                changeRequest.commitChanges { error in
                    if let error = error {
                        print("Error updating profile: \(error.localizedDescription)")
                    }
                }

                print("Sign-up successful")
            }
        }
    }

    func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = nil

        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                print("Sign-in successful")
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            // The state change listener will handle the rest
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upgradeAnonymousUser(name: String, email: String, password: String) {
        guard let currentUser = Auth.auth().currentUser, currentUser.isAnonymous else {
            errorMessage = "No anonymous user to upgrade"
            return
        }

        isLoading = true
        errorMessage = nil

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        currentUser.link(with: credential) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                // Update profile with name
                let changeRequest = result?.user.createProfileChangeRequest()
                changeRequest?.displayName = name
                changeRequest?.commitChanges { error in
                    if let error = error {
                        print("Error updating profile: \(error.localizedDescription)")
                    }
                }

                print("Anonymous user upgrade successful")
            }
        }
    }

    func resetPassword(email: String) {
        isLoading = true
        errorMessage = nil

        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    print("Password reset email sent")
                }
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }
}