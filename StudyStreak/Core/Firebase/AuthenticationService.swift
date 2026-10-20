import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

@MainActor
final class AuthenticationService {
    let auth = Auth.auth()

    func signUp(email: String, password: String) async throws {
        _ = try await auth.createUser(withEmail: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        _ = try await auth.signIn(withEmail: email, password: password)
    }

    func sendPasswordReset(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }

    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID, !clientID.isEmpty else {
            throw AccountError.googleNotConfigured
        }
        let reversedID = clientID.split(separator: ".").reversed().joined(separator: ".")
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        guard schemes.contains(reversedID) else { throw AccountError.missingGoogleURLScheme }
        guard let presenter = presentingController() else { throw AccountError.missingPresenter }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        } catch {
            let nsError = error as NSError
            if nsError.domain == kGIDSignInErrorDomain && nsError.code == GIDSignInError.Code.canceled.rawValue {
                throw CancellationError()
            }
            throw error
        }
        guard let idToken = result.user.idToken?.tokenString else { throw AccountError.invalidGoogleToken }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        _ = try await auth.signIn(with: credential)
    }

    func signOut() throws {
        try auth.signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    private func presentingController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
