import SwiftUI
import AppKit

public enum CommandPaletteCategory: String, CaseIterable {
    case servers = "Servers & Hosts"
    case sftp = "SFTP File Browser"
    case snippets = "Quick Snippets"
    case workspaces = "Workspaces"
    case actions = "Quick Actions & Tools"
}

public struct CommandPaletteItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let iconName: String
    public let category: CommandPaletteCategory
    public let action: () -> Void
}

public struct CommandPaletteView: View {
    @Binding public var isPresented: Bool
    
    @EnvironmentObject private var hostStore: HostStore
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var snippetStore: SnippetStore
    @EnvironmentObject private var sessionManager: TerminalSessionManager
    @EnvironmentObject private var navManager: AppNavigationManager
    @EnvironmentObject private var securityManager: SecurityManager
    
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var keyMonitor: Any? = nil
    @FocusState private var isSearchFocused: Bool
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    private var allItems: [CommandPaletteItem] {
        var items: [CommandPaletteItem] = []
        
        // 1. Hosts
        for host in hostStore.hosts {
            items.append(CommandPaletteItem(
                title: "Connect: \(host.displayTitle)",
                subtitle: "SSH: \(host.connectionString)",
                iconName: host.iconName,
                category: .servers,
                action: {
                    let jh = host.jumpHostId.flatMap { jid in hostStore.hosts.first(where: { $0.id == jid }) }
                    sessionManager.openHost(host, jumpHost: jh)
                    navManager.navigateToTerminal()
                }
            ))
            
            items.append(CommandPaletteItem(
                title: "SFTP: \(host.displayTitle)",
                subtitle: "Browse remote filesystem on \(host.hostname)",
                iconName: "folder.badge.gear",
                category: .sftp,
                action: {
                    navManager.navigateToSFTP(for: host.id)
                }
            ))
        }
        
        // 2. Snippets
        for snippet in snippetStore.snippets {
            items.append(CommandPaletteItem(
                title: "Run Snippet: \(snippet.title)",
                subtitle: snippet.command,
                iconName: "applescript",
                category: .snippets,
                action: {
                    sessionManager.sendSnippet(snippet)
                    navManager.navigateToTerminal()
                }
            ))
        }
        
        // 3. Workspaces
        items.append(CommandPaletteItem(
            title: "Switch Workspace: All Workspaces",
            subtitle: "Show all servers without filter",
            iconName: "globe",
            category: .workspaces,
            action: {
                workspaceStore.activeWorkspaceId = nil
            }
        ))
        for ws in workspaceStore.workspaces {
            items.append(CommandPaletteItem(
                title: "Switch Workspace: \(ws.name)",
                subtitle: ws.isProduction ? "Production Environment [PROD]" : "Filtered view",
                iconName: ws.iconName,
                category: .workspaces,
                action: {
                    workspaceStore.activeWorkspaceId = ws.id
                }
            ))
        }
        
        // 4. Quick Actions
        items.append(CommandPaletteItem(
            title: "New Local Terminal Tab",
            subtitle: "Open zsh terminal (⌘T)",
            iconName: "terminal.fill",
            category: .actions,
            action: {
                sessionManager.openLocalSession()
                navManager.navigateToTerminal()
            }
        ))
        
        items.append(CommandPaletteItem(
            title: "Split Vertically",
            subtitle: "Split active pane side-by-side (⌘D)",
            iconName: "rectangle.split.2x1",
            category: .actions,
            action: {
                sessionManager.splitActiveTabVertically()
                navManager.navigateToTerminal()
            }
        ))
        
        items.append(CommandPaletteItem(
            title: "Split Horizontally",
            subtitle: "Split active pane top-bottom (⌘⇧D)",
            iconName: "rectangle.split.1x2",
            category: .actions,
            action: {
                sessionManager.splitActiveTabHorizontally()
                navManager.navigateToTerminal()
            }
        ))
        
        items.append(CommandPaletteItem(
            title: "Toggle Broadcast Input",
            subtitle: "Mirror keystrokes to all split panes",
            iconName: "antenna.radiowaves.left.and.right",
            category: .actions,
            action: {
                sessionManager.toggleActiveTabBroadcast()
            }
        ))
        
        items.append(CommandPaletteItem(
            title: "Open Shell Config (.zshrc)",
            subtitle: "Edit env variables, plugins, aliases, and PATH",
            iconName: "terminal.badge.gearshape",
            category: .actions,
            action: {
                navManager.selectedNav = .zshrc
            }
        ))
        
        items.append(CommandPaletteItem(
            title: "Open SSH Keys Vault",
            subtitle: "Manage ~/.ssh keys, generate ED25519/RSA",
            iconName: "key.fill",
            category: .actions,
            action: {
                navManager.selectedNav = .sshKeys
            }
        ))
        
        items.append(CommandPaletteItem(
            title: "Open SSH Config Editor",
            subtitle: "Manage OpenSSH host aliases and ProxyJump",
            iconName: "slider.horizontal.2.square",
            category: .actions,
            action: {
                navManager.selectedNav = .sshConfig
            }
        ))
        
        items.append(CommandPaletteItem(
            title: "Open Port Forwarding Tunnels",
            subtitle: "Manage Local, Remote, and SOCKS5 tunnels",
            iconName: "point.3.connected.trianglepath.dotted",
            category: .actions,
            action: {
                navManager.selectedNav = .tunnels
            }
        ))
        
        items.append(CommandPaletteItem(
            title: "Lock Application Now",
            subtitle: "Biometric Touch ID / Password lock (⌘L)",
            iconName: "lock.fill",
            category: .actions,
            action: {
                securityManager.lockNow()
            }
        ))
        
        return items
    }
    
    private var filteredItems: [CommandPaletteItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return allItems
        }
        let query = searchText.lowercased()
        return allItems.filter {
            $0.title.lowercased().contains(query) ||
            $0.subtitle.lowercased().contains(query) ||
            $0.category.rawValue.lowercased().contains(query)
        }
    }
    
    public var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Palette Container
            VStack(spacing: 0) {
                // Search Input Header
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                    
                    TextField("Type a command, host, snippet, or tool... (ESC to close)", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .focused($isSearchFocused)
                        .onSubmit {
                            executeCurrentItem()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Results List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            if filteredItems.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "questionmark.folder")
                                            .font(.system(size: 32))
                                            .foregroundColor(.secondary.opacity(0.5))
                                        Text("No matching commands found")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 40)
                                    Spacer()
                                }
                            } else {
                                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                    let isSelected = index == selectedIndex
                                    
                                    HStack(spacing: 12) {
                                        Image(systemName: item.iconName)
                                            .font(.system(size: 14))
                                            .foregroundColor(isSelected ? .accentColor : .secondary)
                                            .frame(width: 24)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title)
                                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                                .foregroundColor(isSelected ? .primary : .primary.opacity(0.9))
                                            Text(item.subtitle)
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(item.category.rawValue)
                                            .font(.system(size: 9, weight: .medium))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                                    )
                                    .contentShape(Rectangle())
                                    .id(index)
                                    .onTapGesture {
                                        item.action()
                                        isPresented = false
                                    }
                                }
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 380)
                    .onChange(of: selectedIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
                
                Divider()
                
                // Footer
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("↵").font(.caption).fontWeight(.bold).padding(.horizontal, 4).padding(.vertical, 1).background(RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.08)))
                        Text("Execute").font(.caption2).foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Text("↑↓").font(.caption).fontWeight(.bold).padding(.horizontal, 4).padding(.vertical, 1).background(RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.08)))
                        Text("Navigate").font(.caption2).foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Text("esc").font(.caption).fontWeight(.bold).padding(.horizontal, 4).padding(.vertical, 1).background(RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.08)))
                        Text("Close").font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Terminas Command Palette")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))
            }
            .frame(width: 580)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.35), radius: 24, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )
        }
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
            setupKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
    }
    
    private func setupKeyboardMonitor() {
        removeKeyboardMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isPresented else { return event }
            
            // Down Arrow (keyCode 125)
            if event.keyCode == 125 {
                if !filteredItems.isEmpty {
                    selectedIndex = min(filteredItems.count - 1, selectedIndex + 1)
                }
                return nil
            }
            
            // Up Arrow (keyCode 126)
            if event.keyCode == 126 {
                if !filteredItems.isEmpty {
                    selectedIndex = max(0, selectedIndex - 1)
                }
                return nil
            }
            
            // Escape (keyCode 53)
            if event.keyCode == 53 {
                isPresented = false
                return nil
            }
            
            // Return / Enter (keyCode 36)
            if event.keyCode == 36 {
                executeCurrentItem()
                return nil
            }
            
            return event
        }
    }
    
    private func removeKeyboardMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    private func executeCurrentItem() {
        guard filteredItems.indices.contains(selectedIndex) else { return }
        filteredItems[selectedIndex].action()
        isPresented = false
    }
}
