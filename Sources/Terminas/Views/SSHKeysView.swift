import SwiftUI
import AppKit

public struct SSHKeysView: View {
    @EnvironmentObject private var keyManager: SSHKeyManager
    @EnvironmentObject private var navManager: AppNavigationManager
    @State private var showingGenerateSheet = false
    @State private var viewingKey: SSHKeyItem? = nil
    @State private var copiedKeyId: String? = nil
    @State private var searchText = ""
    
    public init() {}
    
    private var filteredKeys: [SSHKeyItem] {
        if searchText.isEmpty { return keyManager.keys }
        return keyManager.keys.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.algorithm.localizedCaseInsensitiveContains(searchText) ||
            $0.comment.localizedCaseInsensitiveContains(searchText) ||
            $0.fingerprint.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SSH Keys & Identifiers")
                        .font(.headline)
                    Text("Manage public/private key pairs in ~/.ssh. Copy public keys directly to GitHub or GitLab.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { keyManager.scanKeys() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh keys from ~/.ssh")
                
                Button(action: { showingGenerateSheet = true }) {
                    Label("Generate Key Pair", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .detailHeaderPadding(defaultLeading: 0, collapsedLeading: 104)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 6)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search keys by name, comment, or algorithm...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            if filteredKeys.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "key.fill")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(keyManager.keys.isEmpty ? "No SSH Keys Found" : "No Keys Matching Search")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Generate a new ED25519 or RSA key pair for GitHub, GitLab, and remote servers.")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    Button(action: { showingGenerateSheet = true }) {
                        Label("Generate First SSH Key", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredKeys) { key in
                        HStack(alignment: .center, spacing: 14) {
                            // Icon Badge
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(algoColor(key.algorithm).opacity(0.15))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "key.fill")
                                    .foregroundColor(algoColor(key.algorithm))
                                    .font(.system(size: 16))
                            }
                            
                            // Key details
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(key.name)
                                        .font(.system(size: 14, weight: .semibold))
                                    
                                    Text(key.algorithm)
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(algoColor(key.algorithm).opacity(0.15)))
                                        .foregroundColor(algoColor(key.algorithm))
                                    
                                    if !key.comment.isEmpty {
                                        Text(key.comment)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                HStack(spacing: 6) {
                                    Text(key.fingerprint)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    
                                    Text("•")
                                        .foregroundColor(.secondary.opacity(0.5))
                                    
                                    Text(displayPath(key.path))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary.opacity(0.8))
                                }
                            }
                            
                            Spacer()
                            
                            // Copy Public Key Button (For GitHub/GitLab)
                            Button(action: { copyPublicKey(key) }) {
                                HStack(spacing: 5) {
                                    Image(systemName: copiedKeyId == key.id ? "checkmark" : "doc.on.doc")
                                    Text(copiedKeyId == key.id ? "Copied!" : "Copy Public Key")
                                }
                                .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                            .tint(copiedKeyId == key.id ? .green : .accentColor)
                            .help("Copy public key string (ssh-ed25519 ...) to paste into GitHub/GitLab")
                            
                            // View Details
                            Button(action: { viewingKey = key }) {
                                Image(systemName: "eye")
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            .help("View public key content")
                        }
                        .padding(.vertical, 6)
                        .contextMenu {
                            Button(action: { copyPublicKey(key) }) {
                                Label("Copy Public Key (for GitHub/GitLab)", systemImage: "doc.on.doc")
                            }
                            Button(action: { copyPath(key.path) }) {
                                Label("Copy Private Key Path", systemImage: "doc")
                            }
                            Button(action: { viewingKey = key }) {
                                Label("View Public Key", systemImage: "eye")
                            }
                            Divider()
                            Button(role: .destructive, action: { keyManager.deleteKey(key) }) {
                                Label("Delete Key Pair", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingGenerateSheet) {
            GenerateSSHKeySheet()
        }
        .sheet(item: $viewingKey) { key in
            ViewSSHKeySheet(key: key)
        }
    }
    
    private func copyPublicKey(_ key: SSHKeyItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(key.publicKeyContent, forType: .string)
        withAnimation {
            copiedKeyId = key.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if copiedKeyId == key.id {
                withAnimation {
                    copiedKeyId = nil
                }
            }
        }
    }
    
    private func copyPath(_ path: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }
    
    private func displayPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
    
    private func algoColor(_ algo: String) -> Color {
        if algo.contains("ED25519") { return .green }
        if algo.contains("RSA") { return .purple }
        if algo.contains("ECDSA") { return .blue }
        return .orange
    }
}

private struct ViewSSHKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    let key: SSHKeyItem
    @State private var copied = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.accentColor)
                Text("Public Key: \(key.name).pub")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Algorithm: \(key.algorithm)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Fingerprint: \(key.fingerprint)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Paste this public key into GitHub ➔ Settings ➔ SSH Keys or remote server ~/.ssh/authorized_keys:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ScrollView {
                    Text(key.publicKeyContent)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .textSelection(.enabled)
                }
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                .frame(height: 140)
                
                HStack {
                    Spacer()
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(key.publicKeyContent, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied to Clipboard!" : "Copy for GitHub / GitLab")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .padding()
        }
        .frame(width: 560, height: 320)
    }
}
