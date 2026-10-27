import SwiftUI

public struct QuickConnectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onConnect: (HostItem) -> Void
    
    @State private var connectionString: String = ""
    @State private var password: String = ""
    @State private var defaultUsername: String = "root"
    
    public init(onConnect: @escaping (HostItem) -> Void) {
        self.onConnect = onConnect
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.orange)
                Text("Quick Connect")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            
            Text("Enter a hostname, IP address, or full SSH URI (e.g. user@192.168.1.50:2222):")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("username@hostname:port", text: $connectionString)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .onSubmit { connect() }
                
                SecureField("Password (Optional - auto-logins if provided)", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .onSubmit { connect() }
            }
            
            HStack {
                Spacer()
                Button("Connect") { connect() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(connectionString.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 440)
    }
    
    private func connect() {
        let trimmed = connectionString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        var user = "root"
        var host = trimmed
        var port = 22
        
        // Parse user@
        if let atIndex = host.firstIndex(of: "@") {
            user = String(host[..<atIndex])
            host = String(host[host.index(after: atIndex)...])
        }
        
        // Parse :port
        if let colonIndex = host.lastIndex(of: ":") {
            let portStr = String(host[host.index(after: colonIndex)...])
            if let p = Int(portStr) {
                port = p
                host = String(host[..<colonIndex])
            }
        }
        
        let trimmedPass = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = HostItem(
            label: "Quick: \(user)@\(host)",
            hostname: host,
            port: port,
            username: user,
            authType: trimmedPass.isEmpty ? .agent : .password,
            tags: ["Quick"],
            colorHex: "#FF9500",
            iconName: "bolt.fill"
        )
        
        if !trimmedPass.isEmpty {
            _ = KeychainService.savePassword(for: item.id, password: trimmedPass)
        }
        
        onConnect(item)
        dismiss()
    }
}
