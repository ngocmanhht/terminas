import SwiftUI
import AppKit

public struct PanesContainerView: View {
    @ObservedObject public var tab: SessionTab
    @EnvironmentObject private var sessionManager: TerminalSessionManager
    
    public init(tab: SessionTab) {
        self.tab = tab
    }
    
    public var body: some View {
        Group {
            switch tab.panes.count {
            case 0:
                Color.clear
            case 1:
                paneItemView(tab.panes[0])
            case 2:
                if tab.splitOrientation == .vertical {
                    HStack(spacing: 2) {
                        paneItemView(tab.panes[0])
                        paneItemView(tab.panes[1])
                    }
                } else {
                    VStack(spacing: 2) {
                        paneItemView(tab.panes[0])
                        paneItemView(tab.panes[1])
                    }
                }
            case 3:
                if tab.splitOrientation == .vertical {
                    HStack(spacing: 2) {
                        paneItemView(tab.panes[0])
                        VStack(spacing: 2) {
                            paneItemView(tab.panes[1])
                            paneItemView(tab.panes[2])
                        }
                    }
                } else {
                    VStack(spacing: 2) {
                        paneItemView(tab.panes[0])
                        HStack(spacing: 2) {
                            paneItemView(tab.panes[1])
                            paneItemView(tab.panes[2])
                        }
                    }
                }
            default: // 4 panes
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        paneItemView(tab.panes[0])
                        paneItemView(tab.panes[1])
                    }
                    HStack(spacing: 2) {
                        paneItemView(tab.panes[2])
                        paneItemView(tab.panes[3])
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func paneItemView(_ pane: TerminalPane) -> some View {
        let isActive = tab.activePaneId == pane.id
        
        VStack(spacing: 0) {
            // Pane Header (shown when 2 or more panes exist)
            if tab.panes.count > 1 {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                    
                    Text(pane.title)
                        .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? .primary : .secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: { tab.closePane(id: pane.id) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close this split pane")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
            }
            
            // Terminal View with Reconnect overlay
            ZStack {
                TerminalViewRepresentable(terminalView: pane.terminalView)
                    .id(pane.terminalViewID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if case .terminated(let exitCode) = pane.status {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.slash.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Pane Disconnected")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Ended\(exitCode != nil ? " (code \(exitCode!))" : "").")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Reconnect") {
                                pane.reconnect()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            
                            if tab.panes.count > 1 {
                                Button(action: { tab.closePane(id: pane.id) }) {
                                    Image(systemName: "xmark")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.windowBackgroundColor).opacity(0.96))
                                .shadow(radius: 6)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .transition(.opacity)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            tab.activePaneId = pane.id
        }
        .overlay(
            Rectangle()
                .stroke(isActive && tab.panes.count > 1 ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 1.5)
        )
    }
}
