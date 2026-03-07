import SwiftUI

enum Theme {
    /// Warm off-white — the "fresh sheet of paper" feel Things is known for
    static let background = Color(red: 0.968, green: 0.961, blue: 0.950)
    /// Slightly warmer/darker tone for side panels
    static let panel      = Color(red: 0.922, green: 0.914, blue: 0.902)
    /// Muted blue accent, similar to Things' task-check colour
    static let accent     = Color(red: 0.31,  green: 0.56,  blue: 0.95)
    /// White card background for photo thumbnails
    static let card       = Color.white
    /// Soft chip/tag pill background
    static let chipBg     = Color(red: 0.31,  green: 0.56,  blue: 0.95).opacity(0.13)
}
