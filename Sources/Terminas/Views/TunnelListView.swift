import SwiftUI

public struct TunnelListView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var hostStore: HostStore
    @EnvironmentObject private var tunnelManager: TunnelManager
    @EnvironmentObject private var navManager: AppNavigationManager
    
    @State private var showingAddSheet = false
    @State private var editingTunnel: TunnelItem? = nil
    
    public init() {}
    
    private var filteredTunnels: [TunnelItem] {
        let currentWsId = workspaceStore.activeWorkspaceId
        return tunnelManager.tunnels.filter { currentWsId == nil || $0.workspaceId == nil || $0.workspaceId == currentWsId }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header description
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SSH Port Forwarding & Tunnels")
                        .font(.headline)
                    Text("Securely forward ports or create SOCKS5 proxies through your SSH hosts.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                WorkspacePickerButton()
                Button(action: { showingAddSheet = true }) {
                    Label("Add Tunnel", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .detailHeaderPadding(defaultLeading: 0, collapsedLeading: 104)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 6)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if filteredTunnels.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No Port Forwarding Tunnels")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Forward local database ports (MySQL, Redis, Mongo) securely via SSH.")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    Button(action: { showingAddSheet = true }) {
                        Label("Create First Tunnel", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredTunnels) { tunnel in
                        let host = hostStore.hosts.first(where: { $0.id == tunnel.hostId })
                        let isActive = tunnelManager.isTunnelActive(tunnel)
                        let error = tunnelManager.tunnelErrors[tunnel.id]
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center, spacing: 12) {
                                // Status Indicator
                                Circle()
                                    .fill(isActive ? Color.green : (error != nil ? Color.red : Color.gray.opacity(0.4)))
                                    .frame(width: 10, height: 10)
                                    .shadow(color: isActive ? Color.green.opacity(0.6) : Color.clear, radius: 4)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(tunnel.name)
                                            .font(.system(size: 14, weight: .semibold))
                                        
                                        Text(tunnel.tunnelType.shortName)
                                            .font(.system(size: 10, weight: .medium))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.triangle.swap")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        Text(tunnel.forwardingSummary)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let host = host {
                                        HStack(spacing: 4) {
                                            Image(systemName: host.iconName)
                                                .font(.system(size: 10))
                                            Text("via \(host.displayTitle)")
                                                .font(.system(size: 11))
                                        }
                                        .foregroundColor(.secondary.opacity(0.8))
                                    }
                                }
                                
                                Spacer()
                                
                                // Toggle button
                                Button(action: {
                                    tunnelManager.toggleTunnel(tunnel, host: host)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: isActive ? "stop.fill" : "play.fill")
                                        Text(isActive ? "Stop" : "Start")
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                }
                                .buttonStyle(.bordered)
                                .tint(isActive ? .red : .accentColor)
                            }
                            
                            if let error = error {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 11))
                                    Text(error)
                                        .font(.system(size: 11))
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.red.opacity(0.08)))
                            }
                        }
                        .padding(.vertical, 8)
                        .contextMenu {
                            Button(action: {
                                tunnelManager.toggleTunnel(tunnel, host: host)
                            }) {
                                Label(isActive ? "Stop Tunnel" : "Start Tunnel", systemImage: isActive ? "stop" : "play")
                            }
                            Button(action: { editingTunnel = tunnel }) {
                                Label("Edit Tunnel", systemImage: "pencil")
                            }
                            Button(role: .destructive, action: {
                                tunnelManager.delete(tunnel)
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            TunnelEditSheet(tunnel: nil) { newTunnel in
                var t = newTunnel
                t.workspaceId = workspaceStore.activeWorkspaceId
                tunnelManager.add(t)
            }
        }
        .sheet(item: $editingTunnel) { t in
            TunnelEditSheet(tunnel: t) { updated in
                tunnelManager.update(updated)
            }
        }
    }
}

public struct TunnelEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var hostStore: HostStore
    
    private let initialTunnel: TunnelItem?
    private let onSave: (TunnelItem) -> Void
    
    @State private var name: String
    @State private var hostId: UUID
    @State private var tunnelType: TunnelType
    @State private var localPort: Int
    @State private var remoteHost: String
    @State private var remotePort: Int
    
    public init(tunnel: TunnelItem?, onSave: @escaping (TunnelItem) -> Void) {
        self.initialTunnel = tunnel
        self.onSave = onSave
        
        _name = State(initialValue: tunnel?.name ?? "")
        _hostId = State(initialValue: tunnel?.hostId ?? UUID())
        _tunnelType = State(initialValue: tunnel?.tunnelType ?? .local)
        _localPort = State(initialValue: tunnel?.localPort ?? 8080)
        _remoteHost = State(initialValue: tunnel?.remoteHost ?? "127.0.0.1")
        _remotePort = State(initialValue: tunnel?.remotePort ?? 8080)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(initialTunnel == nil ? "New Port Forwarding Tunnel" : "Edit Tunnel")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || hostStore.hosts.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            Form {
                Section("General") {
                    TextField("Tunnel Name (e.g. Remote Redis)", text: $name)
                    
                    Picker("SSH Host:", selection: $hostId) {
                        ForEach(hostStore.hosts) { host in
                            Text(host.displayTitle).tag(host.id)
                        }
                    }
                }
                
                Section("Forwarding Type") {
                    Picker("Type:", selection: $tunnelType) {
                        ForEach(TunnelType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                Section("Port Settings") {
                    HStack {
                        Text("Local Port:")
                            .frame(width: 100, alignment: .leading)
                        TextField("8080", value: $localPort, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    if tunnelType != .socks {
                        HStack {
                            Text("Remote Host:")
                                .frame(width: 100, alignment: .leading)
                            TextField("127.0.0.1", text: $remoteHost)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text("Remote Port:")
                                .frame(width: 100, alignment: .leading)
                            TextField("8080", value: $remotePort, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 480, height: 420)
        .onAppear {
            if (initialTunnel == nil || hostId == UUID()), let firstHost = hostStore.hosts.first {
                hostId = firstHost.id
            }
        }
    }
    
    private func save() {
        var tunnel = initialTunnel ?? TunnelItem(
            name: name,
            hostId: hostId,
            tunnelType: tunnelType,
            localPort: localPort,
            remoteHost: remoteHost,
            remotePort: remotePort
        )
        tunnel.name = name.trimmingCharacters(in: .whitespaces)
        tunnel.hostId = hostId
        tunnel.tunnelType = tunnelType
        tunnel.localPort = localPort
        tunnel.remoteHost = remoteHost.trimmingCharacters(in: .whitespaces)
        tunnel.remotePort = remotePort
        
        onSave(tunnel)
        dismiss()
    }
}
