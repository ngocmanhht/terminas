import Foundation
import AppKit
import SwiftTerm

@MainActor
public enum TerminalThemeApplicator {
    public static func apply(to view: LocalProcessTerminalView) {
        let themeName = UserDefaults.standard.string(forKey: "terminalTheme") ?? "Dracula"
        let fontName = UserDefaults.standard.string(forKey: "terminalFontFamily") ?? "SF Mono"
        let fontSize = UserDefaults.standard.double(forKey: "terminalFontSize") == 0 ? 13.0 : UserDefaults.standard.double(forKey: "terminalFontSize")
        
        let theme = TerminalTheme.theme(named: themeName)
        
        // Apply Font
        let font: NSFont
        if fontName == "SF Mono" {
            font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        } else if let custom = NSFont(name: fontName, size: fontSize) {
            font = custom
        } else {
            font = NSFont.userFixedPitchFont(ofSize: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
        view.font = font
        
        // Colors
        if let bg = NSColor(hexString: theme.backgroundHex) {
            view.nativeBackgroundColor = bg
        }
        if let fg = NSColor(hexString: theme.foregroundHex) {
            view.nativeForegroundColor = fg
        }
        if let sel = NSColor(hexString: theme.selectionHex) {
            view.selectedTextBackgroundColor = sel
        }
        if let caret = NSColor(hexString: theme.caretHex) {
            view.caretColor = caret
        }
        
        // Install 16 ANSI colors
        let swiftTermColors: [SwiftTerm.Color] = theme.ansiHex.compactMap { hex in
            let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
            var rgb: UInt64 = 0
            guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
            let r = UInt16(((rgb & 0xFF0000) >> 16) * 257)
            let g = UInt16(((rgb & 0x00FF00) >> 8) * 257)
            let b = UInt16((rgb & 0x0000FF) * 257)
            return SwiftTerm.Color(red: r, green: g, blue: b)
        }
        if swiftTermColors.count == 16 {
            view.installColors(swiftTermColors)
        }
    }
}
