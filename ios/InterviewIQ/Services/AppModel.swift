import Foundation
import Observation
import Supabase

/// App-wide state: auth session, profile and interviews.
@MainActor
@Observable
final class AppModel {
    enum AuthState: Equatable {
        case loading
        case signedOut
        case signedIn(userID: UUID, email: String)
    }

    private(set) var authState: AuthState = .loading
    private(set) var profile: UserProfile?
    private(set) var interviews: [Interview] = []
    private(set) var isRefreshing = false
    var loadError: String?

    private var authTask: Task<Void, Never>?

    var email: String {
        if case let .signedIn(_, email) = authState { return email }
        return ""
    }

    var displayName: String {
        if let first = profile?.firstName, !first.isEmpty { return first }
        return email.split(separator: "@").first.map(String.init) ?? ""
    }

    func start() {
        guard authTask == nil else { return }
        authTask = Task { [weak self] in
            for await (_, session) in supabase.auth.authStateChanges {
                guard let self else { return }
                // A stored session may be expired; the SDK refreshes it before the next request.
                if let session {
                    let previous = self.authState
                    self.authState = .signedIn(userID: session.user.id, email: session.user.email ?? "")
                    // Load data on sign-in or account switch, not on every token refresh.
                    if previous != self.authState { await self.refresh() }
                } else {
                    self.authState = .signedOut
                    self.profile = nil
                    self.interviews = []
                }
            }
        }
    }

    func refresh() async {
        guard case let .signedIn(userID, _) = authState else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            async let profile = InterviewRepository.profile(userID: userID)
            async let interviews = InterviewRepository.interviews(userID: userID)
            self.profile = try await profile
            self.interviews = try await interviews
            loadError = nil
        } catch {
            loadError = "Couldn't load your interviews. Pull down to try again."
        }
    }

    // MARK: Auth

    func sendCode(to email: String) async throws {
        try await supabase.auth.signInWithOTP(email: email)
    }

    func verify(email: String, code: String) async throws {
        _ = try await supabase.auth.verifyOTP(email: email, token: code, type: .email)
    }

    /// Handles a magic-link or Universal Link that opens the app.
    func handle(url: URL) async {
        _ = try? await supabase.auth.session(from: url)
    }

    func signOut() async {
        try? await supabase.auth.signOut()
    }
}
