import SwiftUI

public struct TerminalTabsView: View {
    @EnvironmentObject private var sessionManager: TerminalSessionManager
    @EnvironmentObject private var snippetStore: SnippetStore
    @EnvironmentObject private var navManager: AppNavigationManager
    
    @State private var showingSnippetMenu = false
    @State private var broadcastCommandInput = ""
    
    public init() {}
    
    private var activeTab: SessionTab? {
        sessionManager.activeTab
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if sessionManager.tabs.isEmpty {
                // Empty state when no tabs are open
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "terminal")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No Active Sessions")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text("Pick a host from the sidebar, or launch a local shell session.")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    Button(action: { sessionManager.openLocalSession() }) {
                        Label("Open Local Shell", systemImage: "terminal.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            } else {
                // Tab Bar
                HStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(Array(sessionManager.tabs.enumerated()), id: \.element.id) { index, tab in
                                let isActive = sessionManager.activeTabId == tab.id
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(tabStatusColor(tab.status))
                                        .frame(width: 7, height: 7)
                                    
                                    Image(systemName: tab.isLocal ? "laptopcomputer" : (tab.host?.iconName ?? "server.rack"))
                                        .font(.system(size: 11))
                                        .foregroundColor(isActive ? .accentColor : .secondary)
                                    
                                    Text(tab.title)
                                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                                        .foregroundColor(isActive ? .primary : .secondary)
                                        .lineLimit(1)
                                    
                                    if tab.panes.count > 1 {
                                        Text("\(tab.panes.count)P")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                                    }
                                    
                                    if index < 9 {
                                        Text("⌘\(index + 1)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary.opacity(0.6))
                                    }
                                    
                                    Button(action: { sessionManager.closeTab(id: tab.id) }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(2)
                                    .contentShape(Rectangle())
                                    .help("Close Tab (⌘W)")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    ZStack(alignment: .bottom) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isActive ? Color(NSColor.controlBackgroundColor) : Color.clear)
                                        if isActive {
                                            Rectangle()
                                                .fill(Color.accentColor)
                                                .frame(height: 2)
                                                .padding(.horizontal, 4)
                                        }
                                    }
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    sessionManager.activeTabId = tab.id
                                }
                                .contextMenu {
                                    Button(action: { activeTab?.splitVertically() }) {
                                        Label("Split Vertically", systemImage: "rectangle.split.2x1")
                                    }
                                    Button(action: { activeTab?.splitHorizontally() }) {
                                        Label("Split Horizontally", systemImage: "rectangle.split.1x2")
                                    }
                                    Divider()
                                    Button(action: { sessionManager.duplicateTab(id: tab.id) }) {
                                        Label("Duplicate Tab", systemImage: "plus.square.on.square")
                                    }
                                    Divider()
                                    Button(action: { sessionManager.closeTab(id: tab.id) }) {
                                        Label("Close Tab", systemImage: "xmark")
                                    }
                                    Button(action: { sessionManager.closeOtherTabs(id: tab.id) }) {
                                        Label("Close Other Tabs", systemImage: "xmark.circle")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    
                    Spacer()
                    
                    // Split & Broadcast Action Buttons
                    if let active = activeTab {
                        HStack(spacing: 6) {
                            Button(action: { active.splitVertically() }) {
                                Image(systemName: "rectangle.split.2x1")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .help("Split Vertically (⌘D)")
                            .disabled(active.panes.count >= 4)
                            
                            Button(action: { active.splitHorizontally() }) {
                                Image(systemName: "rectangle.split.1x2")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .help("Split Horizontally (⌘⇧D)")
                            .disabled(active.panes.count >= 4)
                            
                            Button(action: { sessionManager.toggleActiveTabBroadcast() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.system(size: 11))
                                    if active.isBroadcastEnabled {
                                        Text("Broadcast")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(active.isBroadcastEnabled ? Color.red : Color.clear)
                                )
                                .foregroundColor(active.isBroadcastEnabled ? .white : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Toggle Broadcast Input to All Panes")
                        }
                        .padding(.horizontal, 6)
                        
                        Divider().frame(height: 16)
                    }
                    
                    // Quick Snippet Picker Button
                    Menu {
                        ForEach(snippetStore.snippets) { snippet in
                            Button(action: { sessionManager.sendSnippet(snippet) }) {
                                HStack {
                                    Text(snippet.title)
                                    Spacer()
                                    Text(snippet.category).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "applescript")
                            Text("Snippets")
                                .font(.system(size: 11))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .padding(.horizontal, 6)
                    
                    // New Local Tab Button
                    Button(action: { sessionManager.openLocalSession() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 10)
                    .help("New Local Shell Tab (⌘T)")
                }
                .detailHeaderPadding(defaultLeading: 0, collapsedLeading: 114)
                .padding(.top, 4)
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                // Broadcast Active Notification Banner
                if let active = activeTab, active.isBroadcastEnabled {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text("Broadcast ON: Keystrokes mirror to all \(active.panes.count) panes.")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        HStack {
                            Image(systemName: "terminal")
                                .foregroundColor(.secondary)
                                .font(.system(size: 10))
                            TextField("Type command and press Enter to broadcast...", text: $broadcastCommandInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .onSubmit {
                                    let cmd = broadcastCommandInput.trimmingCharacters(in: .whitespaces)
                                    if !cmd.isEmpty {
                                        active.broadcastCommand(cmd)
                                        broadcastCommandInput = ""
                                    }
                                }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                        .frame(maxWidth: 320)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.1))
                    
                    Divider()
                }
                
                // Active Terminal View with Server Stats Bar & Split Panes
                if let activeTab = sessionManager.activeTab {
                    VStack(spacing: 0) {
                        ServerStatsBarView(monitor: activeTab.monitor, tabTitle: activeTab.title, host: activeTab.host)
                        Divider()
                        PanesContainerView(tab: activeTab)
                    }
                }
            }
        }
        .background(
            ZStack {
                // Tab switching shortcuts ⌘1..⌘9
                ForEach(0..<min(9, sessionManager.tabs.count), id: \.self) { idx in
                    Button("") {
                        sessionManager.selectTab(at: idx)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(idx + 1)")), modifiers: .command)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                }
                
                // Split shortcuts ⌘D & ⌘⇧D
                Button("") {
                    activeTab?.splitVertically()
                }
                .keyboardShortcut("d", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                
                Button("") {
                    activeTab?.splitHorizontally()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .frame(width: 0, height: 0)
                .opacity(0)
            }
        )
    }
    
    private func tabStatusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .terminated:
            return .red
        }
    }
}
