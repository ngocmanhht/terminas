import SwiftUI

public struct GenerateSSHKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var keyManager: SSHKeyManager
    
    @State private var algorithm: KeyAlgorithm = .ed25519
    @State private var filename: String = "id_ed25519"
    @State private var comment: String = ""
    @State private var passphrase: String = ""
    @State private var confirmPassphrase: String = ""
    
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var generatedKey: SSHKeyItem? = nil
    @State private var hasCopied = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.accentColor)
                Text(generatedKey == nil ? "Generate New SSH Key Pair" : "Key Pair Generated Successfully!")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            
            Divider()
            
            if let key = generatedKey {
                // Success Screen
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 46))
                        .foregroundColor(.green)
                    
                    VStack(spacing: 4) {
                        Text("Your \(key.algorithm) key pair is ready")
                            .font(.headline)
                        Text("Saved to ~/.ssh/\(key.name) and ~/.ssh/\(key.name).pub")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Public Key (Paste into GitHub, GitLab, or remote server):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            Text(key.publicKeyContent)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .textSelection(.enabled)
                        }
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        .frame(height: 100)
                    }
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(key.publicKeyContent, forType: .string)
                        hasCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { hasCopied = false }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                            Text(hasCopied ? "Copied to Clipboard!" : "Copy Public Key for GitHub / GitLab")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
                .frame(width: 520)
            } else {
                // Configuration Form
                Form {
                    Section("Algorithm") {
                        Picker("Type:", selection: $algorithm) {
                            ForEach(KeyAlgorithm.allCases) { algo in
                                Text(algo.rawValue).tag(algo)
                            }
                        }
                        .onChange(of: algorithm) { _, newAlgo in
                            if filename.starts(with: "id_") {
                                filename = newAlgo.defaultFilename
                            }
                        }
                        
                        Text("ED25519 is the modern cryptographic standard recommended by GitHub and OpenSSH for speed and security.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Section("File Name & Comment") {
                        HStack {
                            Text("Filename:")
                                .frame(width: 90, alignment: .leading)
                            TextField("id_ed25519", text: $filename)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text("Comment:")
                                .frame(width: 90, alignment: .leading)
                            TextField("e.g. user@mac or email@company.com", text: $comment)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    Section("Passphrase (Optional)") {
                        HStack {
                            Text("Passphrase:")
                                .frame(width: 90, alignment: .leading)
                            SecureField("Leave empty for no passphrase", text: $passphrase)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        if !passphrase.isEmpty {
                            HStack {
                                Text("Confirm:")
                                    .frame(width: 90, alignment: .leading)
                                SecureField("Repeat passphrase", text: $confirmPassphrase)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    
                    if let err = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .formStyle(.grouped)
                .padding()
                .frame(width: 520, height: 420)
                
                Divider()
                
                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }
                    Button(action: generate) {
                        HStack(spacing: 6) {
                            if isGenerating {
                                ProgressView().controlSize(.small)
                            }
                            Text("Generate Key Pair")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating || filename.trimmingCharacters(in: .whitespaces).isEmpty || (!passphrase.isEmpty && passphrase != confirmPassphrase))
                }
                .padding()
            }
        }
        .onAppear {
            let user = NSUserName()
            self.comment = "\(user)@mac"
        }
    }
    
    private func generate() {
        isGenerating = true
        errorMessage = nil
        
        Task {
            do {
                let key = try await keyManager.generateKey(
                    algorithm: algorithm,
                    filename: filename,
                    comment: comment,
                    passphrase: passphrase
                )
                self.isGenerating = false
                self.generatedKey = key
            } catch {
                self.isGenerating = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
