import AppKit
import SwiftUI

struct WindowFrameResetter: NSViewRepresentable {
    let isEnabled: Bool
    let trigger: Int
    let targetSize: CGSize

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard isEnabled else { return }
            guard context.coordinator.lastTrigger != trigger else { return }
            guard let window = view.window else { return }
            context.coordinator.lastTrigger = trigger

            let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame
            let newFrame = MainWindowSizing.frame(
                currentFrame: window.frame,
                targetSize: targetSize,
                visibleFrame: visibleFrame
            )
            guard window.frame != newFrame else { return }
            window.setFrame(newFrame, display: true, animate: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastTrigger: Int?
    }
}
