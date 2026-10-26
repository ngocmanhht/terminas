import SwiftUI
import AppKit

public struct AppLockOverlayView: View {
    @ObservedObject var securityManager: SecurityManager
    
    public init(securityManager: SecurityManager) {
        self.securityManager = securityManager
    }
    
    public var body: some View {
        ZStack {
            // Visual effect blur background
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
            
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // App Icon
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 84, height: 84)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                
                VStack(spacing: 6) {
                    Text("Terminas is Locked")
                        .font(.system(size: 20, weight: .bold))
                    
                    Text("Authenticate with Touch ID or your Mac user password to access Terminas.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
                
                if let error = securityManager.authErrorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.12)))
                }
                
                Button(action: {
                    securityManager.promptUnlock()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "touchid")
                            .font(.system(size: 16))
                        Text("Unlock with Touch ID / Password")
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(securityManager.isAuthenticating)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.85))
                    .shadow(color: Color.black.opacity(0.2), radius: 25, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .onAppear {
            securityManager.promptUnlock()
        }
    }
}

// NSVisualEffectView representable for blur
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
