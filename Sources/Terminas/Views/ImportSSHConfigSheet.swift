import SwiftUI

public struct ImportSSHConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var hostStore: HostStore
    
    @State private var discoveredHosts: [HostItem] = []
    @State private var selectedHostIds: Set<UUID> = []
    @State private var targetWorkspaceId: UUID? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .foregroundColor(.accentColor)
                Text("Import Hosts from ~/.ssh/config")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            
            Divider()
            
            if discoveredHosts.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No Hosts Found in ~/.ssh/config")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Make sure your ~/.ssh/config file contains 'Host' definitions.")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                    Spacer()
                }
                .frame(width: 480, height: 260)
            } else {
                VStack(spacing: 12) {
                    // Subheader with Select All & Workspace Picker
                    HStack {
                        Button(selectedHostIds.count == discoveredHosts.count ? "Deselect All" : "Select All") {
                            if selectedHostIds.count == discoveredHosts.count {
                                selectedHostIds.removeAll()
                            } else {
                                selectedHostIds = Set(discoveredHosts.map { $0.id })
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        
                        Spacer()
                        
                        Picker("Target Workspace:", selection: $targetWorkspaceId) {
                            Text("All / Global").tag(nil as UUID?)
                            ForEach(workspaceStore.workspaces) { ws in
                                Text(ws.name).tag(ws.id as UUID?)
                            }
                        }
                        .frame(width: 240)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Host list
                    List(discoveredHosts) { host in
                        HStack(spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { selectedHostIds.contains(host.id) },
                                set: { selected in
                                    if selected {
                                        selectedHostIds.insert(host.id)
                                    } else {
                                        selectedHostIds.remove(host.id)
                                    }
                                }
                            ))
                            .labelsHidden()
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(host.label)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("(\(host.username)@\(host.hostname):\(host.port))")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                
                                if !host.keyPath.isEmpty {
                                    Text("Key: \(host.keyPath)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary.opacity(0.8))
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                    .listStyle(.inset)
                    
                    Divider()
                    
                    // Footer Actions
                    HStack {
                        Text("\(selectedHostIds.count) of \(discoveredHosts.count) hosts selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Import Selected Hosts") {
                            importSelected()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedHostIds.isEmpty)
                    }
                    .padding()
                }
                .frame(width: 540, height: 420)
            }
        }
        .onAppear {
            self.discoveredHosts = SSHConfigParser.parseDefaultConfigFile()
            self.selectedHostIds = Set(discoveredHosts.map { $0.id })
            self.targetWorkspaceId = workspaceStore.activeWorkspaceId
        }
    }
    
    private func importSelected() {
        let toImport = discoveredHosts.filter { selectedHostIds.contains($0.id) }
        for var item in toImport {
            item.workspaceId = targetWorkspaceId
            // Ensure unique ID
            item.id = UUID()
            hostStore.add(item)
        }
        dismiss()
    }
}
