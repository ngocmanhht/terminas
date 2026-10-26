import Foundation
import AppKit
import SwiftTerm

public struct TerminalTheme: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public var name: String
    public var backgroundHex: String
    public var foregroundHex: String
    public var selectionHex: String
    public var caretHex: String
    public var ansiHex: [String]
    
    public static let dracula = TerminalTheme(
        name: "Dracula",
        backgroundHex: "#282a36",
        foregroundHex: "#f8f8f2",
        selectionHex: "#44475a",
        caretHex: "#f8f8f2",
        ansiHex: [
            "#21222c", "#ff5555", "#50fa7b", "#f1fa8c",
            "#bd93f9", "#ff79c6", "#8be9fd", "#f8f8f2",
            "#6272a4", "#ff6e6e", "#69ff94", "#ffffa5",
            "#d6acff", "#ff92df", "#a4ffff", "#ffffff"
        ]
    )
    
    public static let oneDark = TerminalTheme(
        name: "One Dark",
        backgroundHex: "#282c34",
        foregroundHex: "#abb2bf",
        selectionHex: "#3e4451",
        caretHex: "#528bff",
        ansiHex: [
            "#282c34", "#e06c75", "#98c379", "#e5c07b",
            "#61afef", "#c678dd", "#56b6c2", "#abb2bf",
            "#5c6370", "#e06c75", "#98c379", "#e5c07b",
            "#61afef", "#c678dd", "#56b6c2", "#ffffff"
        ]
    )
    
    public static let monokai = TerminalTheme(
        name: "Monokai",
        backgroundHex: "#272822",
        foregroundHex: "#f8f8f2",
        selectionHex: "#49483e",
        caretHex: "#f8f8f0",
        ansiHex: [
            "#272822", "#f92672", "#a6e22e", "#f4bf75",
            "#66d9ef", "#ae81ff", "#a1efe4", "#f8f8f2",
            "#75715e", "#f92672", "#a6e22e", "#f4bf75",
            "#66d9ef", "#ae81ff", "#a1efe4", "#f9f8f5"
        ]
    )
    
    public static let nord = TerminalTheme(
        name: "Nord",
        backgroundHex: "#2e3440",
        foregroundHex: "#d8dee9",
        selectionHex: "#434c5e",
        caretHex: "#d8dee9",
        ansiHex: [
            "#3b4252", "#bf616a", "#a3be8c", "#ebcb8b",
            "#81a1c1", "#b48ead", "#88c0d0", "#e5e9f0",
            "#4c566a", "#bf616a", "#a3be8c", "#ebcb8b",
            "#81a1c1", "#b48ead", "#8fbcbb", "#eceff4"
        ]
    )
    
    public static let macosDark = TerminalTheme(
        name: "macOS Dark",
        backgroundHex: "#1e1e1e",
        foregroundHex: "#ffffff",
        selectionHex: "#264f78",
        caretHex: "#007aff",
        ansiHex: [
            "#000000", "#c91b00", "#00c200", "#c7c400",
            "#0225c7", "#ca30c7", "#00c5c7", "#c7c7c7",
            "#686868", "#ff6e67", "#5ff967", "#fefb67",
            "#6871ff", "#ff76ff", "#5ffdff", "#feffff"
        ]
    )
    
    public static let allThemes: [TerminalTheme] = [
        .dracula,
        .oneDark,
        .monokai,
        .nord,
        .macosDark
    ]
    
    public static func theme(named name: String) -> TerminalTheme {
        allThemes.first { $0.name == name } ?? .dracula
    }
}

extension NSColor {
    convenience init?(hexString: String) {
        var hexSanitized = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
