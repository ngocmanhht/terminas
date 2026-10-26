import SwiftUI

public struct HostRowView: View {
    @EnvironmentObject private var navManager: AppNavigationManager
    @ObservedObject private var healthChecker = HostHealthChecker.shared
    
    public let host: HostItem
    public let onConnect: () -> Void
    public let onEdit: () -> Void
    public let onDuplicate: () -> Void
    public let onDelete: () -> Void
    
    @State private var isHovered = false
    
    public init(
        host: HostItem,
        onConnect: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDuplicate: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.host = host
        self.onConnect = onConnect
        self.onEdit = onEdit
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
    }
    
    private var badgeColor: Color {
        Color(hex: host.colorHex) ?? .blue
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(badgeColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: host.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(badgeColor)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(host.displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                    
                    if host.port != 22 {
                        Text(":\(host.port)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    if host.autoElevate {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.shield.fill")
                                .font(.system(size: 8))
                            Text(host.elevateMethod == .su ? "su: \(host.elevateUser)" : "sudo")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.18)))
                        .foregroundColor(.orange)
                    }
                    
                    if host.jumpHostId != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 8))
                            Text("Bastion")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.purple.opacity(0.18)))
                        .foregroundColor(.purple)
                    }
                    
                    // Live Health Ping Dot
                    healthIndicatorView
                }
                
                HStack(spacing: 6) {
                    Text(host.connectionString)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Label(host.authType.rawValue, systemImage: host.authType.iconName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                if !host.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(host.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // SFTP Quick Button
            Button(action: { navManager.navigateToSFTP(for: host.id) }) {
                Image(systemName: "folder.badge.gear")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help("Open SFTP File Browser for \(host.displayTitle)")
            
            // Connect Button (visible or highlighted on hover)
            Button(action: onConnect) {
                HStack(spacing: 5) {
                    Image(systemName: "terminal.fill")
                    Text("Connect")
                }
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(badgeColor)
            .opacity(isHovered ? 1.0 : 0.85)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onConnect()
        }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(action: onConnect) {
                Label("Connect", systemImage: "terminal")
            }
            Button(action: { navManager.navigateToSFTP(for: host.id) }) {
                Label("Open SFTP Browser", systemImage: "folder.badge.gear")
            }
            Button(action: { healthChecker.checkHost(host) }) {
                Label("Check Ping / Reachability", systemImage: "waveform.path.ecg")
            }
            Divider()
            Button(action: onEdit) {
                Label("Edit Host", systemImage: "pencil")
            }
            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            Button(action: copySSHCommand) {
                Label("Copy SSH Command", systemImage: "doc.on.clipboard")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func copySSHCommand() {
        var cmd = "ssh \(host.username)@\(host.hostname)"
        if host.port != 22 { cmd += " -p \(host.port)" }
        if host.authType == .keyFile && !host.keyPath.isEmpty {
            cmd += " -i \(host.keyPath)"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
    }
    
    @ViewBuilder
    private var healthIndicatorView: some View {
        if let status = healthChecker.statuses[host.id] {
            switch status.state {
            case .checking:
                HStack(spacing: 3) {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.6)
                    Text("ping...")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            case .online(let ms):
                HStack(spacing: 3) {
                    Circle()
                        .fill(ms < 100 ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text("\(ms)ms")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(ms < 100 ? .green : .orange)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Capsule().fill((ms < 100 ? Color.green : Color.orange).opacity(0.12)))
                .help("Reachable via TCP port \(host.port) (\(ms)ms latency)")
            case .offline(let reason):
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("Offline")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.red.opacity(0.12)))
                .help("Unreachable: \(reason)")
            }
        } else {
            Button(action: { healthChecker.checkHost(host) }) {
                Circle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
            .buttonStyle(.plain)
            .help("Click to check server ping/reachability")
        }
    }
}

// Helper extension for Color from hex string
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}
