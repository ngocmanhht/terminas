import SwiftUI

public struct DetailHeaderPaddingModifier: ViewModifier {
    @EnvironmentObject private var navManager: AppNavigationManager
    public var defaultLeading: CGFloat
    public var collapsedLeading: CGFloat
    
    public init(defaultLeading: CGFloat = 0, collapsedLeading: CGFloat = 108) {
        self.defaultLeading = defaultLeading
        self.collapsedLeading = collapsedLeading
    }
    
    public func body(content: Content) -> some View {
        HStack(alignment: .center, spacing: 10) {
            if navManager.isSidebarCollapsed {
                Button(action: {
                    navManager.toggleSidebar()
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .frame(width: 26, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Show Sidebar (⌃⌘S)")
                .padding(.leading, navManager.isFullScreen ? 4 : 68)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
            
            content
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.88), value: navManager.isSidebarCollapsed)
    }
}

public extension View {
    func detailHeaderPadding(defaultLeading: CGFloat = 0, collapsedLeading: CGFloat = 108) -> some View {
        self.modifier(DetailHeaderPaddingModifier(defaultLeading: defaultLeading, collapsedLeading: collapsedLeading))
    }
}
