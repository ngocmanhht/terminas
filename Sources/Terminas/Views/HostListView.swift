import SwiftUI

public enum HostSortOrder: String, CaseIterable, Identifiable {
    case name = "Name (A-Z)"
    case recent = "Recent Connections"
    case fastestPing = "Fastest Ping"
    
    public var id: String { rawValue }
}

public struct HostListView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var hostStore: HostStore
    @EnvironmentObject private var sessionManager: TerminalSessionManager
    @EnvironmentObject private var navManager: AppNavigationManager
    
    @State private var searchText = ""
    @State private var selectedTag: String? = nil
    @State private var showingAddSheet = false
    @State private var editingHost: HostItem? = nil
    @State private var showingQuickConnect = false
    @State private var showingImportSSHConfig = false
    @State private var sortOrder: HostSortOrder = .name
    @FocusState private var isSearchFocused: Bool
    
    public init() {}
    
    private var filteredHosts: [HostItem] {
        let currentWsId = workspaceStore.activeWorkspaceId
        var list = hostStore.hosts.filter { host in
            let matchesWs = currentWsId == nil || host.workspaceId == nil || host.workspaceId == currentWsId
            
            let matchesSearch = searchText.isEmpty ||
                host.label.localizedCaseInsensitiveContains(searchText) ||
                host.hostname.localizedCaseInsensitiveContains(searchText) ||
                host.username.localizedCaseInsensitiveContains(searchText) ||
                host.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            
            let matchesTag = selectedTag == nil || host.tags.contains(selectedTag!)
            
            return matchesWs && matchesSearch && matchesTag
        }
        
        switch sortOrder {
        case .name:
            list.sort { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
        case .recent:
            list.sort { ($0.lastConnectedAt ?? Date.distantPast) > ($1.lastConnectedAt ?? Date.distantPast) }
        case .fastestPing:
            list.sort { h1, h2 in
                let ms1: Int
                if let s = HostHealthChecker.shared.statuses[h1.id], case .online(let ms) = s.state { ms1 = ms } else { ms1 = 99999 }
                let ms2: Int
                if let s = HostHealthChecker.shared.statuses[h2.id], case .online(let ms) = s.state { ms2 = ms } else { ms2 = 99999 }
                return ms1 < ms2
            }
        }
        return list
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search, Tags & Action Bar
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    // Workspace Picker
                    WorkspacePickerButton()
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search hosts by name, IP, user, or tag... (⌘F)", text: $searchText)
                            .textFieldStyle(.plain)
                            .focused($isSearchFocused)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Sort Menu
                        Menu {
                            ForEach(HostSortOrder.allCases) { order in
                                Button(action: { sortOrder = order }) {
                                    HStack {
                                        Text(order.rawValue)
                                        if sortOrder == order { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .help("Sort: \(sortOrder.rawValue)")
                        
                        // Hidden shortcut button for ⌘F
                        Button("") {
                            isSearchFocused = true
                        }
                        .keyboardShortcut("f", modifiers: .command)
                        .frame(width: 0, height: 0)
                        .opacity(0)
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
                    
                    // Quick Action Buttons
                    Button(action: { HostHealthChecker.shared.checkAll(hosts: filteredHosts) }) {
                        Image(systemName: "waveform.path.ecg")
                    }
                    .buttonStyle(.bordered)
                    .help("Ping and check health for all visible hosts")
                    
                    Button(action: { sessionManager.openLocalSession() }) {
                        Label("Local", systemImage: "terminal")
                    }
                    .buttonStyle(.bordered)
                    .help("Open local macOS terminal (⌘T)")
                    
                    Button(action: { showingQuickConnect = true }) {
                        Label("Quick Connect", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.bordered)
                    .help("Quick connect to an IP or hostname")
                    
                    Button(action: { showingImportSSHConfig = true }) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .help("Import hosts from ~/.ssh/config")
                    
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Host", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Add new SSH host")
                }
                .detailHeaderPadding(defaultLeading: 0, collapsedLeading: 108)
                
                // Tags Bar
                if !hostStore.allTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            TagPill(
                                title: "All",
                                isSelected: selectedTag == nil,
                                onSelect: { selectedTag = nil }
                            )
                            ForEach(hostStore.allTags, id: \.self) { tag in
                                TagPill(
                                    title: tag,
                                    isSelected: selectedTag == tag,
                                    onSelect: {
                                        selectedTag = (selectedTag == tag) ? nil : tag
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Host List or Empty State
            if filteredHosts.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "server.rack")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(hostStore.hosts.isEmpty ? "No Hosts Yet" : "No Hosts Found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(hostStore.hosts.isEmpty ? "Add your first SSH server or connect directly." : "Try clearing your search filter.")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    Button(action: { showingAddSheet = true }) {
                        Label("Add SSH Host", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredHosts) { host in
                        HostRowView(
                            host: host,
                            onConnect: {
                                let jh = host.jumpHostId.flatMap { jid in hostStore.hosts.first(where: { $0.id == jid }) }
                                sessionManager.openHost(host, jumpHost: jh)
                            },
                            onEdit: { editingHost = host },
                            onDuplicate: { hostStore.duplicate(host) },
                            onDelete: { hostStore.delete(host) }
                        )
                        .listRowSeparator(.visible)
                        .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            HostEditSheet(host: nil, defaultWorkspaceId: workspaceStore.activeWorkspaceId) { newHost, password, elevatePassword in
                hostStore.add(newHost)
                if let pwd = password {
                    _ = KeychainService.savePassword(for: newHost.id, password: pwd)
                }
                if let elevatePwd = elevatePassword {
                    _ = KeychainService.saveElevatePassword(for: newHost.id, password: elevatePwd)
                }
            }
        }
        .sheet(item: $editingHost) { host in
            HostEditSheet(host: host) { updatedHost, password, elevatePassword in
                hostStore.update(updatedHost)
                if let pwd = password, !pwd.isEmpty {
                    _ = KeychainService.savePassword(for: updatedHost.id, password: pwd)
                } else {
                    KeychainService.deletePassword(for: updatedHost.id)
                }
                if let elevatePwd = elevatePassword, !elevatePwd.isEmpty {
                    _ = KeychainService.saveElevatePassword(for: updatedHost.id, password: elevatePwd)
                } else {
                    KeychainService.deleteElevatePassword(for: updatedHost.id)
                }
            }
        }
        .sheet(isPresented: $showingQuickConnect) {
            QuickConnectSheet { quickHost in
                sessionManager.openHost(quickHost)
            }
        }
        .sheet(isPresented: $showingImportSSHConfig) {
            ImportSSHConfigSheet()
        }
        .onAppear {
            HostHealthChecker.shared.checkAll(hosts: filteredHosts)
        }
    }
}

private struct TagPill: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
