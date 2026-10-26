import SwiftUI
import AppKit

public enum NavigationItem: Hashable {
    case hosts
    case terminal
    case sftp
    case tunnels
    case sshKeys
    case sshConfig
    case zshrc
    case snippets
    case settings
}

public struct MainContentView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var hostStore: HostStore
    @EnvironmentObject private var snippetStore: SnippetStore
    @EnvironmentObject private var sessionManager: TerminalSessionManager
    @EnvironmentObject private var tunnelManager: TunnelManager
    @EnvironmentObject private var keyManager: SSHKeyManager
    @EnvironmentObject private var configManager: SSHConfigFileManager
    @EnvironmentObject private var zshManager: ZshConfigFileManager
    @EnvironmentObject private var navManager: AppNavigationManager
    
    public init() {}
    
    private var filteredHostsCount: Int {
        let wsId = workspaceStore.activeWorkspaceId
        return hostStore.hosts.filter { wsId == nil || $0.workspaceId == nil || $0.workspaceId == wsId }.count
    }
    
    private var filteredSnippetsCount: Int {
        let wsId = workspaceStore.activeWorkspaceId
        return snippetStore.snippets.filter { wsId == nil || $0.workspaceId == nil || $0.workspaceId == wsId }.count
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            if !navManager.isSidebarCollapsed {
                VStack(spacing: 0) {
                    // Top bar for traffic lights & sidebar toggle button
                    HStack(spacing: 0) {
                        Spacer()
                            .frame(width: navManager.isFullScreen ? 12 : 76)
                        
                        Button(action: {
                            navManager.toggleSidebar()
                        }) {
                            Image(systemName: "sidebar.left")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                                .frame(width: 26, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Hide Sidebar (⌃⌘S)")
                        
                        Spacer()
                    }
                    .frame(height: 38)
                    
                    // Global Workspace Switcher at top of Sidebar
                    WorkspaceSwitcherHeaderView()
                        .padding(.horizontal, 4)
                        .padding(.bottom, 2)
                    
                    List(selection: Binding(
                        get: { navManager.selectedNav },
                        set: { if let v = $0 { navManager.selectedNav = v } }
                    )) {
                        Section("SERVERS") {
                            HStack {
                                Label("Hosts", systemImage: "server.rack")
                                Spacer()
                                Text("\(filteredHostsCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .tag(NavigationItem.hosts)
                            
                            Label("SFTP Browser", systemImage: "folder.badge.gear")
                                .tag(NavigationItem.sftp)
                            
                            HStack {
                                Label("Port Forwarding", systemImage: "point.3.connected.trianglepath.dotted")
                                Spacer()
                                if !tunnelManager.activeTunnelIds.isEmpty {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 7, height: 7)
                                }
                            }
                            .tag(NavigationItem.tunnels)
                        }
                        
                        Section("SESSIONS") {
                            HStack {
                                Label("Terminal", systemImage: "terminal")
                                Spacer()
                                if !sessionManager.tabs.isEmpty {
                                    Text("\(sessionManager.tabs.count)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.accentColor))
                                        .foregroundColor(.white)
                                }
                            }
                            .tag(NavigationItem.terminal)
                        }
                        
                        Section("LOCAL DEVICE") {
                            HStack {
                                Label("SSH Keys", systemImage: "key.fill")
                                Spacer()
                                Text("\(keyManager.keys.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .tag(NavigationItem.sshKeys)
                            
                            HStack {
                                Label("SSH Config", systemImage: "slider.horizontal.2.square")
                                Spacer()
                                Text("\(configManager.entries.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .tag(NavigationItem.sshConfig)
                            
                            HStack {
                                Label("Shell Config (.zshrc)", systemImage: "terminal.badge.gearshape")
                                Spacer()
                                Text("zsh")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                                    .foregroundColor(.secondary)
                            }
                            .tag(NavigationItem.zshrc)
                            
                            HStack {
                                Label("Snippets", systemImage: "applescript")
                                Spacer()
                                Text("\(filteredSnippetsCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .tag(NavigationItem.snippets)
                        }
                        
                        Section {
                            Button(action: { navManager.toggleCommandPalette() }) {
                                HStack {
                                    Label("Command Palette", systemImage: "command")
                                    Spacer()
                                    Text("⌘K")
                                        .font(.system(size: 10, design: .monospaced))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Label("Settings", systemImage: "gearshape")
                                .tag(NavigationItem.settings)
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                }
                .frame(width: 235)
                .background(SidebarVisualEffectView().ignoresSafeArea())
                .transition(.move(edge: .leading))
                
                Divider()
                    .ignoresSafeArea()
            }
            
            // Detail Content Pane
            Group {
                switch navManager.selectedNav {
                case .hosts:
                    HostListView()
                case .terminal:
                    TerminalTabsView()
                case .sftp:
                    SFTPBrowserView()
                case .tunnels:
                    TunnelListView()
                case .sshKeys:
                    SSHKeysView()
                case .sshConfig:
                    SSHConfigEditorView()
                case .zshrc:
                    ZshConfigView()
                case .snippets:
                    SnippetsView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: .top)
        .background(WindowChromeConfigurator(isFullScreen: navManager.isFullScreen, isSidebarCollapsed: navManager.isSidebarCollapsed))
        .background(
            Button("") {
                navManager.toggleCommandPalette()
            }
            .keyboardShortcut("k", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
        )
        .onAppear {
            navManager.updateFullScreenState()
        }
        .onChange(of: sessionManager.tabs.count) { oldCount, newCount in
            if newCount > oldCount {
                navManager.navigateToTerminal()
            }
        }
        .onChange(of: sessionManager.activeTabId) { _, newId in
            if newId != nil {
                navManager.navigateToTerminal()
            }
        }
    }
}

private struct SidebarVisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct WindowChromeConfigurator: NSViewRepresentable {
    var isFullScreen: Bool
    var isSidebarCollapsed: Bool
    
    func makeNSView(context: Context) -> WindowObserverView {
        let view = WindowObserverView()
        return view
    }
    
    func updateNSView(_ nsView: WindowObserverView, context: Context) {
        nsView.configureWindow()
    }
    
    final class WindowObserverView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureWindow()
        }
        
        override func layout() {
            super.layout()
            configureWindow()
        }
        
        func configureWindow() {
            guard let window = self.window else { return }
            
            if window.toolbar != nil {
                window.toolbar = nil
            }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            if !window.styleMask.contains(.fullSizeContentView) {
                window.styleMask.insert(.fullSizeContentView)
            }
            
            let inFullScreen = window.styleMask.contains(.fullScreen)
            
            // Align traffic lights vertically with the 38pt header (centerY = 19pt from top)
            for type: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
                if let btn = window.standardWindowButton(type) {
                    btn.isHidden = inFullScreen
                    if !inFullScreen {
                        var f = btn.frame
                        if abs(f.origin.y - 2) > 0.5 {
                            f.origin.y = 2
                            btn.frame = f
                        }
                    }
                }
            }
            
            // Ensure no opaque titlebar container blocks top bar in Full Screen
            if let themeFrame = window.contentView?.superview {
                for sub in themeFrame.subviews {
                    let className = NSStringFromClass(type(of: sub))
                    if className.contains("TitlebarContainer") {
                        sub.isHidden = inFullScreen
                    }
                }
            }
            
            for appWin in NSApp.windows {
                let winClass = NSStringFromClass(type(of: appWin))
                if winClass.contains("ToolbarFullScreen") {
                    appWin.titlebarAppearsTransparent = true
                    appWin.backgroundColor = .clear
                    appWin.isOpaque = false
                    if let content = appWin.contentView {
                        content.isHidden = true
                    }
                }
            }
        }
    }
}
