import SwiftUI

public enum ConfigViewMode: String, CaseIterable, Identifiable {
    case structured = "Host Entries"
    case raw = "Raw ~/.ssh/config"
    
    public var id: String { rawValue }
}

public struct SSHConfigEditorView: View {
    @EnvironmentObject private var configManager: SSHConfigFileManager
    @EnvironmentObject private var navManager: AppNavigationManager
    @State private var viewMode: ConfigViewMode = .structured
    @State private var editingEntry: SSHConfigEntry? = nil
    @State private var showingAddSheet = false
    @State private var rawTextBuffer = ""
    @State private var showSavedAlert = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SSH Configuration (~/.ssh/config)")
                        .font(.headline)
                    Text("Manage OpenSSH host aliases, proxy jump tunnels, and per-host key settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("", selection: $viewMode) {
                    ForEach(ConfigViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                
                if viewMode == .structured {
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Entry", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(action: saveRawText) {
                        Label("Save File", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .detailHeaderPadding(defaultLeading: 0, collapsedLeading: 104)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 6)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if viewMode == .structured {
                // Structured List View
                if configManager.entries.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "slider.horizontal.2.square")
                            .font(.system(size: 42))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No Host Entries in ~/.ssh/config")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Add host configurations or switch to the raw file editor.")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                        
                        Button(action: { showingAddSheet = true }) {
                            Label("Add First Host Entry", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(configManager.entries) { entry in
                            HStack(alignment: .center, spacing: 14) {
                                Image(systemName: "terminal.badge.gear")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 20))
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text("Host \(entry.host)")
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        
                                        if !entry.user.isEmpty {
                                            Text(entry.user)
                                                .font(.system(size: 11, weight: .medium))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 1)
                                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                                        }
                                        
                                        if entry.port != 22 {
                                            Text("Port \(entry.port)")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    HStack(spacing: 8) {
                                        if !entry.hostName.isEmpty {
                                            Text("HostName: \(entry.hostName)")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if !entry.identityFile.isEmpty {
                                            Text("• Key: \(entry.identityFile)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary.opacity(0.8))
                                        }
                                        
                                        if !entry.proxyJump.isEmpty {
                                            Text("• Jump: \(entry.proxyJump)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Button("Edit") {
                                    editingEntry = entry
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.vertical, 4)
                            .contextMenu {
                                Button("Edit Entry") { editingEntry = entry }
                                Button(role: .destructive, action: { configManager.deleteEntry(entry) }) {
                                    Label("Delete Entry", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            } else {
                // Raw File Editor
                VStack(spacing: 0) {
                    TextEditor(text: $rawTextBuffer)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                }
            }
        }
        .onAppear {
            configManager.load()
            rawTextBuffer = configManager.rawConfigText
        }
        .onChange(of: viewMode) { _, mode in
            if mode == .raw {
                rawTextBuffer = configManager.rawConfigText
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            SSHConfigEntryEditSheet(entry: nil) { newEntry in
                configManager.addEntry(newEntry)
            }
        }
        .sheet(item: $editingEntry) { entry in
            SSHConfigEntryEditSheet(entry: entry) { updated in
                configManager.updateEntry(updated)
            }
        }
        .alert("Configuration Saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Successfully updated ~/.ssh/config")
        }
    }
    
    private func saveRawText() {
        configManager.saveRaw(rawTextBuffer)
        showSavedAlert = true
    }
}

public struct SSHConfigEntryEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let initialEntry: SSHConfigEntry?
    private let onSave: (SSHConfigEntry) -> Void
    
    @State private var host: String
    @State private var hostName: String
    @State private var user: String
    @State private var port: Int
    @State private var identityFile: String
    @State private var proxyJump: String
    @State private var forwardAgent: Bool
    
    public init(entry: SSHConfigEntry?, onSave: @escaping (SSHConfigEntry) -> Void) {
        self.initialEntry = entry
        self.onSave = onSave
        
        _host = State(initialValue: entry?.host ?? "")
        _hostName = State(initialValue: entry?.hostName ?? "")
        _user = State(initialValue: entry?.user ?? "")
        _port = State(initialValue: entry?.port ?? 22)
        _identityFile = State(initialValue: entry?.identityFile ?? "")
        _proxyJump = State(initialValue: entry?.proxyJump ?? "")
        _forwardAgent = State(initialValue: entry?.forwardAgent ?? false)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(initialEntry == nil ? "New SSH Config Entry" : "Edit Config Entry")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            Form {
                Section("Host Definition") {
                    HStack {
                        Text("Host Alias:")
                            .frame(width: 100, alignment: .leading)
                        TextField("e.g. github.com, prod-api, jumpbox", text: $host)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("HostName / IP:")
                            .frame(width: 100, alignment: .leading)
                        TextField("e.g. 192.168.1.100 or ssh.github.com", text: $hostName)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Section("Connection Details") {
                    HStack {
                        Text("User:")
                            .frame(width: 100, alignment: .leading)
                        TextField("e.g. git, root, ubuntu", text: $user)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Port:")
                            .frame(width: 100, alignment: .leading)
                        TextField("22", value: $port, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("IdentityFile:")
                            .frame(width: 100, alignment: .leading)
                        TextField("~/.ssh/id_ed25519", text: $identityFile)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") { pickKey() }
                    }
                }
                
                Section("Advanced Routing") {
                    HStack {
                        Text("ProxyJump:")
                            .frame(width: 100, alignment: .leading)
                        TextField("e.g. bastion-server, user@jumpbox:22", text: $proxyJump)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Toggle("ForwardAgent (Share SSH Agent)", isOn: $forwardAgent)
                }
            }
            .formStyle(.grouped)
            .padding()
            .frame(width: 520, height: 420)
        }
    }
    
    private func pickKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: ("~/.ssh" as NSString).expandingTildeInPath)
        if panel.runModal() == .OK, let url = panel.url {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            var path = url.path
            if path.hasPrefix(home) {
                path = "~" + path.dropFirst(home.count)
            }
            self.identityFile = path
        }
    }
    
    private func save() {
        var entry = initialEntry ?? SSHConfigEntry(host: host)
        entry.host = host.trimmingCharacters(in: .whitespaces)
        entry.hostName = hostName.trimmingCharacters(in: .whitespaces)
        entry.user = user.trimmingCharacters(in: .whitespaces)
        entry.port = port
        entry.identityFile = identityFile.trimmingCharacters(in: .whitespaces)
        entry.proxyJump = proxyJump.trimmingCharacters(in: .whitespaces)
        entry.forwardAgent = forwardAgent
        onSave(entry)
        dismiss()
    }
}
