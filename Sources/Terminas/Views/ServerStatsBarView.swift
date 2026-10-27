import SwiftUI

public struct ServerStatsBarView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var navManager: AppNavigationManager
    @ObservedObject var monitor: ServerMonitorService
    let tabTitle: String
    let host: HostItem?
    
    public init(monitor: ServerMonitorService, tabTitle: String, host: HostItem? = nil) {
        self.monitor = monitor
        self.tabTitle = tabTitle
        self.host = host
    }
    
    private var isProductionHost: Bool {
        guard let wsId = host?.workspaceId else { return false }
        return workspaceStore.workspaces.first(where: { $0.id == wsId })?.isProduction == true
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Left: Host Title & Status
            HStack(spacing: 6) {
                if isProductionHost {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 9))
                        Text("PROD")
                            .font(.system(size: 9, weight: .heavy))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.red))
                    .foregroundColor(.white)
                }
                
                Image(systemName: host?.iconName ?? "server.rack")
                    .font(.system(size: 11))
                    .foregroundColor(isProductionHost ? .red : .accentColor)
                
                Text(tabTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            
            Divider()
                .frame(height: 12)
            
            // Middle: Horizontal scrollable badges that never wrap or compress
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // Time
                    StatBadge(
                        icon: "clock.fill",
                        title: "Time",
                        value: cleanTime(monitor.metrics.serverTime),
                        color: .blue
                    )
                    
                    // CPU
                    StatBadge(
                        icon: "cpu",
                        title: "CPU",
                        value: monitor.metrics.cpuDisplay,
                        color: cpuColor(monitor.metrics.cpuPercent),
                        percent: monitor.metrics.cpuPercent
                    )
                    
                    // RAM
                    StatBadge(
                        icon: "memorychip",
                        title: "RAM",
                        value: monitor.metrics.ramDisplay,
                        color: ramColor(monitor.metrics.ramPercent),
                        percent: monitor.metrics.ramPercent
                    )
                    
                    // Disk
                    StatBadge(
                        icon: "internaldrive",
                        title: "Disk",
                        value: monitor.metrics.diskDisplay,
                        color: diskColor(monitor.metrics.diskPercent),
                        percent: monitor.metrics.diskPercent
                    )
                    
                    // Uptime
                    if !monitor.metrics.uptime.isEmpty {
                        StatBadge(
                            icon: "arrow.clockwise.circle",
                            title: "Up",
                            value: monitor.metrics.uptime.trimmingCharacters(in: .whitespacesAndNewlines),
                            color: .secondary
                        )
                    }
                    
                    // Ping
                    if let latency = monitor.metrics.latencyMs {
                        StatBadge(
                            icon: "wifi",
                            title: "Ping",
                            value: "\(latency) ms",
                            color: latencyColor(latency)
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            
            Spacer(minLength: 4)
            
            // Right Action Controls
            HStack(spacing: 6) {
                if let h = host {
                    Button(action: { navManager.navigateToSFTP(for: h.id) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.gear")
                                .font(.system(size: 9))
                            Text("SFTP")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.12)))
                        .foregroundColor(.accentColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.accentColor.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Open SFTP File Browser for \(h.displayTitle)")
                }
                
                Button(action: { monitor.fetchMetrics() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(monitor.isFetching ? 360 : 0))
                        .animation(monitor.isFetching ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: monitor.isFetching)
                        .padding(4)
                        .background(Circle().fill(Color.primary.opacity(0.04)))
                }
                .buttonStyle(.plain)
                .help("Refresh Server Stats")
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .frame(height: 28)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.92))
    }
    
    private func cleanTime(_ timeStr: String) -> String {
        let trimmed = timeStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "--:--:--" { return "--:--:--" }
        // If it contains date like "10:10:09 27/10", extract just time for compact display
        let parts = trimmed.components(separatedBy: " ")
        return parts.first ?? trimmed
    }
    
    private func cpuColor(_ val: Double) -> Color {
        if val > 80 { return .red }
        if val > 50 { return .orange }
        return .green
    }
    
    private func ramColor(_ val: Double) -> Color {
        if val > 85 { return .red }
        if val > 65 { return .orange }
        return .purple
    }
    
    private func diskColor(_ val: Double) -> Color {
        if val > 90 { return .red }
        if val > 75 { return .orange }
        return .cyan
    }
    
    private func latencyColor(_ ms: Int) -> Color {
        if ms < 80 { return .green }
        if ms < 200 { return .orange }
        return .red
    }
}

private struct StatBadge: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    var percent: Double? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(color)
            
            Text(title + ":")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
            
            if let pct = percent, pct > 0 {
                // Mini 18px gauge bar for CPU / RAM / Disk
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 18, height: 3.5)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: 18 * CGFloat(min(1.0, max(0.05, pct / 100.0))), height: 3.5)
                }
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(
            RoundedRectangle(cornerRadius: 4.5)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 4.5)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        )
    }
}
