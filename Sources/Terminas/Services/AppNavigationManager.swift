import Foundation
import SwiftUI
import Combine

@MainActor
public class AppNavigationManager: ObservableObject {
    @Published public var selectedNav: NavigationItem = .hosts
    @Published public var sftpTargetHostId: UUID? = nil
    @Published public var isCommandPalettePresented: Bool = false
    @Published public var isSidebarCollapsed: Bool = false
    @Published public var isFullScreen: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupWindowObservers()
    }
    
    private func setupWindowObservers() {
        let enterNotifications = [
            NSWindow.willEnterFullScreenNotification,
            NSWindow.didEnterFullScreenNotification
        ]
        for name in enterNotifications {
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.isFullScreen = true
                }
                .store(in: &cancellables)
        }
        
        let exitNotifications = [
            NSWindow.willExitFullScreenNotification,
            NSWindow.didExitFullScreenNotification
        ]
        for name in exitNotifications {
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.isFullScreen = false
                }
                .store(in: &cancellables)
        }
    }
    
    public func updateFullScreenState() {
        if let win = NSApp.windows.first(where: { $0.isKeyWindow || $0.isVisible }) {
            self.isFullScreen = win.styleMask.contains(.fullScreen)
        }
    }
    
    public func toggleSidebar() {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
            isSidebarCollapsed.toggle()
        }
    }
    
    public func navigateToTerminal() {
        selectedNav = .terminal
    }
    
    public func navigateToSFTP(for hostId: UUID? = nil) {
        if let hostId = hostId {
            sftpTargetHostId = hostId
        }
        selectedNav = .sftp
    }
    
    public func navigateToHosts() {
        selectedNav = .hosts
    }
    
    public func toggleCommandPalette() {
        isCommandPalettePresented.toggle()
    }
}
