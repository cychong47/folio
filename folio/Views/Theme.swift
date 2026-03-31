import SwiftUI
import AppKit

enum Theme {
    // MARK: - Adaptive colours (work in both light and dark mode)

    /// Warm cream in light mode, dark charcoal in dark mode
    static let background = Color(NSColor(name: nil) { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            : NSColor(red: 0.968, green: 0.961, blue: 0.950, alpha: 1)
    })

    /// Slightly warmer/darker panel (sidebar, gallery)
    static let panel = Color(NSColor(name: nil) { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1)
            : NSColor(red: 0.922, green: 0.914, blue: 0.902, alpha: 1)
    })

    /// Card background for photo thumbnails
    static let card = Color(NSColor(name: nil) { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.20, green: 0.20, blue: 0.21, alpha: 1)
            : NSColor.white
    })

    /// Soft chip/tag pill background
    static let chipBg = Color(NSColor(name: nil) { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.31, green: 0.56, blue: 0.95, alpha: 0.25)
            : NSColor(red: 0.31, green: 0.56, blue: 0.95, alpha: 0.13)
    })

    /// Muted blue accent — same in both modes
    static let accent = Color(red: 0.31, green: 0.56, blue: 0.95)
}
