import SwiftUI
import AppKit

public struct HostEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var hostStore: HostStore
    
    private let initialHost: HostItem?
    private let onSave: (HostItem, String?, String?) -> Void
    
    @State private var label: String
    @State private var hostname: String
    @State private var port: Int
    @State private var username: String
    @State private var authType: AuthType
    @State private var keyPath: String
    @State private var password: String = ""
    @State private var tagsString: String
    @State private var selectedColor: String
    @State private var selectedIcon: String
    @State private var notes: String
    @State private var workspaceId: UUID?
    @State private var jumpHostId: UUID?
    
    // Auto Elevate states
    @State private var autoElevate: Bool
    @State private var elevateMethod: ElevateMethod
    @State private var elevateUser: String
    @State private var customElevateCommand: String
    @State private var elevatePassword: String = ""
    
    private let availableColors = [
        "#0A84FF", // Blue
        "#34C759", // Green
        "#FF9500", // Orange
        "#FF3B30", // Red
        "#AF52DE", // Purple
        "#5856D6", // Indigo
        "#64D2FF", // Cyan
        "#FF2D55"  // Pink
    ]
    
    private let availableIcons = [
        "server.rack",
        "cpu",
        "cloud.fill",
        "laptopcomputer",
        "desktopcomputer",
        "network",
        "bolt.fill",
        "cube.box.fill"
    ]
    
    public init(host: HostItem?, defaultWorkspaceId: UUID? = nil, onSave: @escaping (HostItem, String?, String?) -> Void) {
        self.initialHost = host
        self.onSave = onSave
        
        _label = State(initialValue: host?.label ?? "")
        _hostname = State(initialValue: host?.hostname ?? "")
        _port = State(initialValue: host?.port ?? 22)
        _username = State(initialValue: host?.username ?? "root")
        _authType = State(initialValue: host?.authType ?? .keyFile)
        _keyPath = State(initialValue: host?.keyPath ?? "~/.ssh/id_ed25519")
        _tagsString = State(initialValue: host?.tags.joined(separator: ", ") ?? "")
        _selectedColor = State(initialValue: host?.colorHex ?? "#0A84FF")
        _selectedIcon = State(initialValue: host?.iconName ?? "server.rack")
        _notes = State(initialValue: host?.notes ?? "")
        _workspaceId = State(initialValue: host?.workspaceId ?? defaultWorkspaceId)
        _jumpHostId = State(initialValue: host?.jumpHostId)
        
        _autoElevate = State(initialValue: host?.autoElevate ?? false)
        _elevateMethod = State(initialValue: host?.elevateMethod ?? .su)
        _elevateUser = State(initialValue: host?.elevateUser ?? "root")
        _customElevateCommand = State(initialValue: host?.customElevateCommand ?? "")
        
        if let host = host {
            if let savedPass = KeychainService.getPassword(for: host.id) {
                _password = State(initialValue: savedPass)
            }
            if let savedElevatePass = KeychainService.getElevatePassword(for: host.id) {
                _elevatePassword = State(initialValue: savedElevatePass)
            }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(initialHost == nil ? "New SSH Host" : "Edit Host")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(hostname.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            
            Divider()
            
            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // General Section
                    GroupBox("General") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Label:")
                                    .frame(width: 90, alignment: .trailing)
                                TextField("e.g. Production Web", text: $label)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Text("Workspace:")
                                    .frame(width: 90, alignment: .trailing)
                                Picker("", selection: $workspaceId) {
                                    Text("Global / All Workspaces").tag(nil as UUID?)
                                    ForEach(workspaceStore.workspaces) { ws in
                                        HStack {
                                            Text(ws.name)
                                            if ws.isProduction {
                                                Text("[PROD]")
                                            }
                                        }
                                        .tag(ws.id as UUID?)
                                    }
                                }
                            }
                            
                            HStack {
                                Text("Hostname / IP:")
                                    .frame(width: 90, alignment: .trailing)
                                TextField("e.g. 192.168.1.100 or myserver.com", text: $hostname)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Text("Port:")
                                    .frame(width: 90, alignment: .trailing)
                                TextField("Port", value: $port, formatter: NumberFormatter())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                Spacer()
                            }
                            
                            HStack {
                                Text("Username:")
                                    .frame(width: 90, alignment: .trailing)
                                TextField("e.g. deploy or ubuntu", text: $username)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding(8)
                    }
                    
                    // Authentication Section
                    GroupBox("SSH Authentication") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Method:")
                                    .frame(width: 90, alignment: .trailing)
                                Picker("", selection: $authType) {
                                    ForEach(AuthType.allCases) { type in
                                        Label(type.rawValue, systemImage: type.iconName).tag(type)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            if authType == .keyFile {
                                HStack {
                                    Text("Key Path:")
                                        .frame(width: 90, alignment: .trailing)
                                    TextField("~/.ssh/id_ed25519", text: $keyPath)
                                        .textFieldStyle(.roundedBorder)
                                    Button("Browse...") { pickKeyFile() }
                                }
                            } else if authType == .password {
                                HStack {
                                    Text("Password:")
                                        .frame(width: 90, alignment: .trailing)
                                    SecureField("Saved in macOS Keychain", text: $password)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                        }
                        .padding(8)
                    }
                    
                    // Proxy Jump / Bastion Section
                    GroupBox("Proxy Jump / Bastion Host") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Jump Host:")
                                    .frame(width: 90, alignment: .trailing)
                                Picker("", selection: $jumpHostId) {
                                    Text("Direct Connection (None)").tag(Optional<UUID>.none)
                                    ForEach(hostStore.hosts.filter { $0.id != initialHost?.id }) { h in
                                        Text("\(h.displayTitle) (\(h.hostname))").tag(Optional<UUID>.some(h.id))
                                    }
                                }
                            }
                            if jumpHostId != nil {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.branch")
                                        .foregroundColor(.accentColor)
                                    Text("SSH & SFTP traffic will be automatically tunneled via this Bastion host using OpenSSH -J.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 98)
                            }
                        }
                        .padding(8)
                    }
                    
                    // Auto Elevate & Switch User (su / sudo)
                    GroupBox("Privilege Elevation & User Switch") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Auto switch user / elevate to root after login", isOn: $autoElevate)
                                .fontWeight(.medium)
                            
                            if autoElevate {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Method:")
                                            .frame(width: 100, alignment: .trailing)
                                        Picker("", selection: $elevateMethod) {
                                            ForEach(ElevateMethod.allCases) { m in
                                                Text(m.rawValue).tag(m)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                    }
                                    
                                    if elevateMethod == .su {
                                        HStack {
                                            Text("Target User:")
                                                .frame(width: 100, alignment: .trailing)
                                            TextField("root", text: $elevateUser)
                                                .textFieldStyle(.roundedBorder)
                                        }
                                    } else if elevateMethod == .custom {
                                        HStack {
                                            Text("Command:")
                                                .frame(width: 100, alignment: .trailing)
                                            TextField("e.g. su - appuser", text: $customElevateCommand)
                                                .textFieldStyle(.roundedBorder)
                                        }
                                    }
                                    
                                    HStack {
                                        Text("Root/SU Pass:")
                                            .frame(width: 100, alignment: .trailing)
                                        SecureField("Target user or root password", text: $elevatePassword)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    
                                    Text("Automatically executes when SSH connects and feeds password from Keychain.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 108)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(8)
                    }
                    
                    // Appearance & Tags
                    GroupBox("Appearance & Organization") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Icon:")
                                    .frame(width: 90, alignment: .trailing)
                                HStack(spacing: 10) {
                                    ForEach(availableIcons, id: \.self) { icon in
                                        Button(action: { selectedIcon = icon }) {
                                            Image(systemName: icon)
                                                .font(.system(size: 14))
                                                .frame(width: 28, height: 28)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(selectedIcon == icon ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                Spacer()
                            }
                            
                            HStack {
                                Text("Badge Color:")
                                    .frame(width: 90, alignment: .trailing)
                                HStack(spacing: 10) {
                                    ForEach(availableColors, id: \.self) { hex in
                                        Circle()
                                            .fill(Color(hex: hex) ?? .blue)
                                            .frame(width: 22, height: 22)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: selectedColor == hex ? 2 : 0)
                                            )
                                            .onTapGesture { selectedColor = hex }
                                    }
                                }
                                Spacer()
                            }
                            
                            HStack {
                                Text("Tags:")
                                    .frame(width: 90, alignment: .trailing)
                                TextField("Comma separated (e.g. AWS, Prod, Web)", text: $tagsString)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack(alignment: .top) {
                                Text("Notes:")
                                    .frame(width: 90, alignment: .trailing)
                                TextEditor(text: $notes)
                                    .frame(height: 50)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(8)
                    }
                }
                .padding()
            }
        }
        .frame(width: 530, height: 650)
    }
    
    private func pickKeyFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: ("~/.ssh" as NSString).expandingTildeInPath)
        
        if panel.runModal() == .OK, let url = panel.url {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            var path = url.path
            if path.hasPrefix(home) {
                path = "~" + path.dropFirst(home.count)
            }
            self.keyPath = path
        }
    }
    
    private func save() {
        let tags = tagsString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var host = initialHost ?? HostItem(
            label: label,
            hostname: hostname,
            port: port,
            username: username
        )
        host.label = label
        host.hostname = hostname.trimmingCharacters(in: .whitespaces)
        host.port = port
        host.username = username.trimmingCharacters(in: .whitespaces)
        host.authType = authType
        host.keyPath = keyPath.trimmingCharacters(in: .whitespaces)
        host.tags = tags
        host.colorHex = selectedColor
        host.iconName = selectedIcon
        host.notes = notes
        host.autoElevate = autoElevate
        host.elevateMethod = elevateMethod
        host.elevateUser = elevateUser.trimmingCharacters(in: .whitespaces)
        host.customElevateCommand = customElevateCommand.trimmingCharacters(in: .whitespaces)
        host.workspaceId = workspaceId
        host.jumpHostId = jumpHostId
        
        onSave(host, password.isEmpty ? nil : password, elevatePassword.isEmpty ? nil : elevatePassword)
        dismiss()
    }
}
