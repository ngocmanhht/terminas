import Foundation
import SwiftTerm
import AppKit
import Combine

@MainActor
public class SessionTab: NSObject, ObservableObject, Identifiable {
    public let id: UUID
    @Published public var title: String
    @Published public var panes: [TerminalPane] = []
    @Published public var activePaneId: UUID
    @Published public var splitOrientation: PaneOrientation = .vertical
    @Published public var isBroadcastEnabled: Bool = false
    
    public let host: HostItem?
    public let jumpHost: HostItem?
    public let isLocal: Bool
    
    private var keyMonitor: Any?
    
    public init(id: UUID = UUID(), title: String, host: HostItem? = nil, jumpHost: HostItem? = nil, isLocal: Bool = false) {
        self.id = id
        self.title = title
        self.host = host
        self.jumpHost = jumpHost
        self.isLocal = isLocal
        
        let initialPane = TerminalPane(title: title, host: host, jumpHost: jumpHost, isLocal: isLocal)
        self.activePaneId = initialPane.id
        self.panes = [initialPane]
        super.init()
        initialPane.parentTab = self
        setupKeyMonitoring()
    }
    
    private func setupKeyMonitoring() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isBroadcastEnabled else { return event }
            
            // Check if active pane's terminal view is the first responder
            if let activePane = self.activePane,
               let window = activePane.terminalView?.window,
               window.firstResponder == activePane.terminalView,
               let characters = event.characters, !characters.isEmpty {
                let bytes = ArraySlice(Array(characters.utf8))
                for pane in self.panes where pane.id != activePane.id {
                    pane.terminalView?.send(data: bytes)
                }
            }
            return event
        }
    }
    
    public var activePane: TerminalPane? {
        panes.first(where: { $0.id == activePaneId }) ?? panes.first
    }
    
    public var terminalView: LocalProcessTerminalView! {
        activePane?.terminalView
    }
    
    public var terminalViewID: UUID {
        activePane?.terminalViewID ?? UUID()
    }
    
    public var status: SessionStatus {
        activePane?.status ?? .connected
    }
    
    public var monitor: ServerMonitorService {
        activePane?.monitor ?? ServerMonitorService()
    }
    
    public func start() {
        for pane in panes {
            pane.start()
        }
    }
    
    public func reconnect() {
        activePane?.reconnect()
    }
    
    public func reconnectAll() {
        for pane in panes {
            pane.reconnect()
        }
    }
    
    public func splitVertically(host: HostItem? = nil, jumpHost: HostItem? = nil) {
        guard panes.count < 4 else { return }
        splitOrientation = .vertical
        let targetHost = host ?? activePane?.host
        let targetJump = jumpHost ?? activePane?.jumpHost
        let local = targetHost == nil && (activePane?.isLocal ?? true)
        let paneTitle = targetHost?.label ?? "Terminal \(panes.count + 1)"
        
        let newPane = TerminalPane(title: paneTitle, host: targetHost, jumpHost: targetJump, isLocal: local)
        newPane.parentTab = self
        newPane.start()
        panes.append(newPane)
        activePaneId = newPane.id
    }
    
    public func splitHorizontally(host: HostItem? = nil, jumpHost: HostItem? = nil) {
        guard panes.count < 4 else { return }
        splitOrientation = .horizontal
        let targetHost = host ?? activePane?.host
        let targetJump = jumpHost ?? activePane?.jumpHost
        let local = targetHost == nil && (activePane?.isLocal ?? true)
        let paneTitle = targetHost?.label ?? "Terminal \(panes.count + 1)"
        
        let newPane = TerminalPane(title: paneTitle, host: targetHost, jumpHost: targetJump, isLocal: local)
        newPane.parentTab = self
        newPane.start()
        panes.append(newPane)
        activePaneId = newPane.id
    }
    
    public func closePane(id: UUID) {
        if let idx = panes.firstIndex(where: { $0.id == id }) {
            panes[idx].close()
            panes.remove(at: idx)
            if activePaneId == id {
                activePaneId = panes.first?.id ?? UUID()
            }
        }
    }
    
    public func broadcastCommand(_ command: String) {
        let toSend = "\(command)\n"
        let bytes = ArraySlice(Array(toSend.utf8))
        for pane in panes {
            pane.terminalView?.send(data: bytes)
        }
    }
    
    public func send(text: String, appendNewline: Bool = true) {
        if isBroadcastEnabled {
            broadcastCommand(text)
        } else {
            activePane?.send(text: text, appendNewline: appendNewline)
        }
    }
    
    public func close() {
        if let km = keyMonitor {
            NSEvent.removeMonitor(km)
            keyMonitor = nil
        }
        for pane in panes {
            pane.close()
        }
    }
}
