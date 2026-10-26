import SwiftUI
import AppKit

@main
struct TerminasApp: App {
    @StateObject private var securityManager = SecurityManager()
    @StateObject private var workspaceStore = WorkspaceStore()
    @StateObject private var hostStore = HostStore()
    @StateObject private var snippetStore = SnippetStore()
    @StateObject private var sessionManager = TerminalSessionManager()
    @StateObject private var tunnelManager = TunnelManager()
    @StateObject private var keyManager = SSHKeyManager()
    @StateObject private var configManager = SSHConfigFileManager()
    @StateObject private var zshManager = ZshConfigFileManager()
    @StateObject private var navManager = AppNavigationManager()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                MainContentView()
                    .environmentObject(securityManager)
                    .environmentObject(workspaceStore)
                    .environmentObject(hostStore)
                    .environmentObject(snippetStore)
                    .environmentObject(sessionManager)
                    .environmentObject(tunnelManager)
                    .environmentObject(keyManager)
                    .environmentObject(configManager)
                    .environmentObject(zshManager)
                    .environmentObject(navManager)
                    .frame(minWidth: 960, minHeight: 620)
                
                if navManager.isCommandPalettePresented {
                    CommandPaletteView(isPresented: $navManager.isCommandPalettePresented)
                        .environmentObject(securityManager)
                        .environmentObject(workspaceStore)
                        .environmentObject(hostStore)
                        .environmentObject(snippetStore)
                        .environmentObject(sessionManager)
                        .environmentObject(navManager)
                        .transition(.opacity)
                        .zIndex(90)
                }
                
                if securityManager.isLocked {
                    AppLockOverlayView(securityManager: securityManager)
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Command Palette...") {
                    navManager.toggleCommandPalette()
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Divider()
                
                Button("New Terminal Tab") {
                    sessionManager.openLocalSession()
                    navManager.navigateToTerminal()
                }
                .keyboardShortcut("t", modifiers: .command)
                
                Button("Close Tab") {
                    if let activeId = sessionManager.activeTabId {
                        sessionManager.closeTab(id: activeId)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
                
                Divider()
                
                Button("Lock Terminas") {
                    securityManager.lockNow()
                }
                .keyboardShortcut("l", modifiers: .command)
            }
            
            CommandMenu("Terminal") {
                Button("Split Vertically") {
                    sessionManager.splitActiveTabVertically()
                    navManager.navigateToTerminal()
                }
                .keyboardShortcut("d", modifiers: .command)
                
                Button("Split Horizontally") {
                    sessionManager.splitActiveTabHorizontally()
                    navManager.navigateToTerminal()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Toggle Broadcast Mode") {
                    sessionManager.toggleActiveTabBroadcast()
                }
                .keyboardShortcut("b", modifiers: [.command, .option])
                
                Button("Reconnect Session") {
                    sessionManager.activeTab?.reconnect()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            
            CommandMenu("Navigation") {
                Button("Toggle Sidebar") { navManager.toggleSidebar() }
                    .keyboardShortcut("s", modifiers: [.command, .control])
                Divider()
                Button("Go to Hosts") { navManager.navigateToHosts() }
                    .keyboardShortcut("h", modifiers: [.command, .shift])
                Button("Go to Terminal") { navManager.navigateToTerminal() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Button("Go to SFTP Browser") { navManager.navigateToSFTP() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(securityManager)
        }
        #endif
    }
}
