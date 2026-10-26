import Foundation
import LocalAuthentication
import Combine
import SwiftUI

@MainActor
public class SecurityManager: ObservableObject {
    @Published public var isLocked: Bool = false
    @Published public var isAuthenticating: Bool = false
    @Published public var authErrorMessage: String? = nil
    
    // Settings stored in UserDefaults
    @AppStorage("requireAppLock") public var requireAppLock: Bool = false
    
    public init() {
        if UserDefaults.standard.bool(forKey: "requireAppLock") {
            self.isLocked = true
        }
    }
    
    public func promptUnlock() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        authErrorMessage = nil
        
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        var error: NSError?
        // .deviceOwnerAuthentication prompts Touch ID or falls back to Mac login password
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Authenticate with Touch ID or Mac Password to unlock Terminas"
            
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                Task { @MainActor in
                    self.isAuthenticating = false
                    if success {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.isLocked = false
                        }
                    } else if let authError = authError {
                        self.authErrorMessage = authError.localizedDescription
                    }
                }
            }
        } else {
            isAuthenticating = false
            authErrorMessage = error?.localizedDescription ?? "Device authentication is not available"
            // If device cannot evaluate policy (e.g. headless), don't trap user
            self.isLocked = false
        }
    }
    
    public func lockNow() {
        if requireAppLock {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isLocked = true
            }
        }
    }
}
