import MSAL
import SwiftUI
import UIKit

/// Completes MSAL's broker round trip.
///
/// When Microsoft Authenticator is installed, MSAL brokers sign-in through it
/// rather than a web view: the app leaves, Authenticator authenticates, and the
/// result comes back as an `msauth.<bundle-id>://auth` URL. MSAL cannot see
/// that URL on its own — the app has to hand it over, or the interactive
/// request it is still waiting on never completes and eventually fails as the
/// uninformative MSALErrorInternal (-50000).
///
/// Nothing here is exercised in the simulator, where `brokerAvailability` is
/// `.none` and `ASWebAuthenticationSession` completes its own callback
/// internally. Neither is it exercised on a device without Authenticator, which
/// falls back to the same web view. That is why this was missing: every path
/// that gets tested locally works without it.
@MainActor
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let context = URLContexts.first else { return }

        // `sourceApplication` is how MSAL satisfies itself the response really
        // came from Authenticator and not something else that claimed the
        // scheme, so it is taken from the scene options rather than passed nil.
        let handled = MSALPublicClientApplication.handleMSALResponse(
            context.url,
            sourceApplication: context.options.sourceApplication
        )

        DiagnosticsLog.shared.append(
            "callback \(context.url.scheme ?? "?") from \(context.options.sourceApplication ?? "unknown") handled=\(handled)"
        )
    }
}

/// Exists only to name `SceneDelegate` — a SwiftUI `App` has no other hook for
/// attaching one, and the callback above has nowhere to land without it.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
