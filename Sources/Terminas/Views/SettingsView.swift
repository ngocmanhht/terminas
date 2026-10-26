import SwiftUI
import AppKit

public struct SettingsView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var hostStore: HostStore
    @EnvironmentObject private var snippetStore: SnippetStore
    @EnvironmentObject private var tunnelManager: TunnelManager
    @EnvironmentObject private var navManager: AppNavigationManager
    
    @AppStorage("terminalTheme") private var selectedThemeName: String = "Dracula"
    @AppStorage("terminalFontFamily") private var fontFamily: String = "SF Mono"
    @AppStorage("terminalFontSize") private var fontSize: Double = 13.0
    @AppStorage("defaultUsername") private var defaultUsername: String = "root"
    @AppStorage("defaultPort") private var defaultPort: Int = 22
    @AppStorage("requireAppLock") private var requireAppLock: Bool = false
    
    @State private var showingImportSSHConfig = false
    @State private var backupAlertMessage: String? = nil
    
    private let availableFonts = [
        "SF Mono",
        "Menlo",
        "Monaco",
        "Courier New",
        "JetBrains Mono",
        "Fira Code"
    ]
    
    public init() {}
    
    private var currentTheme: TerminalTheme {
        TerminalTheme.theme(named: selectedThemeName)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.headline)
                    Text("Appearance, terminal font & themes, default ports, and biometric security.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .detailHeaderPadding(defaultLeading: 0, collapsedLeading: 104)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 6)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                Form {
                // Section 1: Themes & Colors
                Section("Terminal Theme & Colors") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Theme Preset:")
                                .frame(width: 120, alignment: .leading)
                            
                            Picker("", selection: $selectedThemeName) {
                                ForEach(TerminalTheme.allThemes) { theme in
                                    Text(theme.name).tag(theme.name)
                                }
                            }
                            .frame(width: 200)
                        }
                        
                        // Live Theme Preview Box
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle().fill(Color.red).frame(width: 8, height: 8)
                                Circle().fill(Color.yellow).frame(width: 8, height: 8)
                                Circle().fill(Color.green).frame(width: 8, height: 8)
                                Spacer()
                                Text(currentTheme.name)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: currentTheme.foregroundHex)?.opacity(0.6) ?? .secondary)
                            }
                            .padding(.bottom, 4)
                            
                            HStack(spacing: 4) {
                                Text("user@terminas")
                                    .foregroundColor(Color(hex: currentTheme.ansiHex[2]) ?? .green)
                                Text(":")
                                    .foregroundColor(Color(hex: currentTheme.foregroundHex) ?? .white)
                                Text("~/projects")
                                    .foregroundColor(Color(hex: currentTheme.ansiHex[4]) ?? .blue)
                                Text("$ ls -la")
                                    .foregroundColor(Color(hex: currentTheme.foregroundHex) ?? .white)
                                Rectangle()
                                    .fill(Color(hex: currentTheme.caretHex) ?? .white)
                                    .frame(width: 7, height: 13)
                            }
                            .font(.system(size: CGFloat(fontSize), design: .monospaced))
                            
                            // 16 ANSI Palette Swatches
                            HStack(spacing: 5) {
                                ForEach(0..<16, id: \.self) { idx in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: currentTheme.ansiHex[idx]) ?? .gray)
                                        .frame(height: 14)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: currentTheme.backgroundHex) ?? Color.black)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .padding(.vertical, 4)
                }
                
                // Section 2: Typography
                Section("Typography") {
                    HStack {
                        Text("Font Family:")
                            .frame(width: 120, alignment: .leading)
                        Picker("", selection: $fontFamily) {
                            ForEach(availableFonts, id: \.self) { font in
                                Text(font).tag(font)
                            }
                        }
                        .frame(width: 200)
                    }
                    
                    HStack {
                        Text("Font Size: \(Int(fontSize)) pt")
                            .frame(width: 120, alignment: .leading)
                        Slider(value: $fontSize, in: 10...26, step: 1)
                            .frame(width: 180)
                        Text("\(Int(fontSize))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Section 3: SSH Defaults
                Section("SSH Defaults") {
                    HStack {
                        Text("Default Username:")
                            .frame(width: 120, alignment: .leading)
                        TextField("root", text: $defaultUsername)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                    }
                    
                    HStack {
                        Text("Default Port:")
                            .frame(width: 120, alignment: .leading)
                        TextField("22", value: $defaultPort, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
                
                // Section 4: Security & Data Privacy
                Section("Security & Data Protection") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Require Touch ID or Mac Password on App Launch", isOn: $requireAppLock)
                            .fontWeight(.medium)
                        
                        Text("Uses Apple's LocalAuthentication framework to protect application access with your Mac user password or Touch ID biometric sensor.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider().padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Data Storage & Encryption Audit:")
                                .font(.system(size: 11, weight: .bold))
                            
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text("SSH & Root Passwords: Encrypted in hardware via Apple Keychain (Secure Enclave).")
                                    .font(.caption)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text("Configuration Vault: Encrypted on disk using military-grade AES-256-GCM (CryptoKit).")
                                    .font(.caption)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text("Master Encryption Key: Cryptographically random 256-bit key protected by Keychain.")
                                    .font(.caption)
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                    }
                    .padding(.vertical, 4)
                }
                
                // Section 5: Backup & Migration
                Section("Backup & Data Migration") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Button(action: exportBackupPrompt) {
                                Label("Export Encrypted Backup...", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(action: restoreBackupPrompt) {
                                Label("Restore from Backup...", systemImage: "square.and.arrow.down")
                            }
                            
                            Button(action: { showingImportSSHConfig = true }) {
                                Label("Import ~/.ssh/config...", systemImage: "terminal")
                            }
                        }
                        
                        Text("Export your servers, workspaces, snippets, and port forwarding tunnels to an encrypted backup file to migrate to a new Mac.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // Section 6: About Terminas
                Section("About Terminas") {
                    HStack(spacing: 14) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .frame(width: 48, height: 48)
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Terminas for macOS")
                                .font(.headline)
                            Text("Version 1.1.0 — Native Swift & SwiftUI Terminal & SSH Client")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Encrypted via Apple Keychain • SwiftTerm Terminal Engine")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom)
        }
        .frame(minWidth: 540, minHeight: 520)
        .sheet(isPresented: $showingImportSSHConfig) {
            ImportSSHConfigSheet()
        }
        .alert(isPresented: Binding(
            get: { backupAlertMessage != nil },
            set: { if !$0 { backupAlertMessage = nil } }
        )) {
            Alert(
                title: Text("Terminas Backup"),
                message: Text(backupAlertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
        }
    }
    
    private func exportBackupPrompt() {
        guard let data = BackupService.createBackup(
            workspaces: workspaceStore.workspaces,
            hosts: hostStore.hosts,
            snippets: snippetStore.snippets,
            tunnels: tunnelManager.tunnels
        ) else {
            backupAlertMessage = "Unable to create backup data."
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Terminas_Backup_\(dateStr).json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url, options: .atomic)
                backupAlertMessage = "Backup exported successfully!"
            } catch {
                backupAlertMessage = "Failed to save backup file: \(error.localizedDescription)"
            }
        }
    }
    
    private func restoreBackupPrompt() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                guard let backup = BackupService.loadBackup(from: data) else {
                    backupAlertMessage = "Invalid or corrupted backup file."
                    return
                }
                
                // Merge or restore
                for ws in backup.workspaces {
                    if !workspaceStore.workspaces.contains(where: { $0.id == ws.id }) {
                        workspaceStore.add(ws)
                    }
                }
                for h in backup.hosts {
                    if !hostStore.hosts.contains(where: { $0.id == h.id }) {
                        hostStore.add(h)
                    }
                }
                for s in backup.snippets {
                    if !snippetStore.snippets.contains(where: { $0.id == s.id }) {
                        snippetStore.add(s)
                    }
                }
                for t in backup.tunnels {
                    if !tunnelManager.tunnels.contains(where: { $0.id == t.id }) {
                        tunnelManager.add(t)
                    }
                }
                backupAlertMessage = "Successfully restored \(backup.hosts.count) hosts, \(backup.snippets.count) snippets, and \(backup.tunnels.count) tunnels!"
            } catch {
                backupAlertMessage = "Failed to read backup file: \(error.localizedDescription)"
            }
        }
    }
}
