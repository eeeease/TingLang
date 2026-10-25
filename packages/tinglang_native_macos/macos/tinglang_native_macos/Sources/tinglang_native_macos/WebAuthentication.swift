import AppKit
import AuthenticationServices

/// Sign-in for the optional cloud services through ASWebAuthenticationSession:
/// the account page runs in the system's browser session (saved passwords and
/// passkeys work there), and the app only receives the callback URL.
@MainActor
final class WebAuthentication: NSObject, ASWebAuthenticationPresentationContextProviding {
  private var session: ASWebAuthenticationSession?
  var anchorWindow: () -> NSWindow? = { nil }

  /// Only https, or http on this machine for development.
  static func isAllowed(_ url: URL) -> Bool {
    switch url.scheme?.lowercased() {
    case "https": return true
    case "http": return ["localhost", "127.0.0.1", "::1"].contains(url.host ?? "")
    default: return false
    }
  }

  func start(_ url: URL, callbackScheme: String, completion: @escaping (Result<String, Error>) -> Void) {
    guard Self.isAllowed(url), !callbackScheme.isEmpty else {
      completion(.failure(PigeonError(code: "invalid", message: "Refusing to open this sign-in address", details: nil)))
      return
    }
    // One sign-in at a time; a second request ends the first.
    session?.cancel()
    let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) {
      [weak self] callback, error in
      // The handler's queue is not documented; only touch state on main.
      DispatchQueue.main.async { MainActor.assumeIsolated { self?.session = nil } }
      if let callback {
        completion(.success(callback.absoluteString))
      } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
        completion(.failure(PigeonError(code: "canceled", message: "The sign-in window was closed", details: nil)))
      } else {
        completion(.failure(PigeonError(code: "failed", message: error?.localizedDescription ?? "Sign-in failed", details: nil)))
      }
    }
    session.presentationContextProvider = self
    // Share the browser's cookies so a signed-in website does not ask again.
    session.prefersEphemeralWebBrowserSession = false
    self.session = session
    if !session.start() {
      self.session = nil
      completion(.failure(PigeonError(code: "failed", message: "Could not open the sign-in window", details: nil)))
    }
  }

  nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    MainActor.assumeIsolated {
      anchorWindow() ?? NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible } ?? NSWindow()
    }
  }
}
