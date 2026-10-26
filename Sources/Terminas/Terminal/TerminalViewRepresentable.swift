import SwiftUI
import SwiftTerm
import AppKit

public struct TerminalViewRepresentable: NSViewRepresentable {
    public let terminalView: LocalProcessTerminalView
    
    public init(terminalView: LocalProcessTerminalView) {
        self.terminalView = terminalView
    }
    
    public func makeNSView(context: Context) -> NSView {
        let container = NSView()
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(terminalView)
        
        NSLayoutConstraint.activate([
            terminalView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            terminalView.topAnchor.constraint(equalTo: container.topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        TerminalThemeApplicator.apply(to: terminalView)
        
        DispatchQueue.main.async {
            self.terminalView.window?.makeFirstResponder(self.terminalView)
        }
        
        return container
    }
    
    public func updateNSView(_ nsView: NSView, context: Context) {
        TerminalThemeApplicator.apply(to: terminalView)
        
        DispatchQueue.main.async {
            self.terminalView.window?.makeFirstResponder(self.terminalView)
        }
    }
}
