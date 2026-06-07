import CoreGraphics

enum MainWindowSizing {
    static let welcomeSize = CGSize(width: 800, height: 430)

    static func frame(
        currentFrame: CGRect,
        targetSize: CGSize = welcomeSize,
        visibleFrame: CGRect
    ) -> CGRect {
        let width = min(targetSize.width, visibleFrame.width)
        let height = min(targetSize.height, visibleFrame.height)
        let centeredX = currentFrame.midX - width / 2
        let centeredY = currentFrame.midY - height / 2
        let x = clamp(centeredX, min: visibleFrame.minX, max: visibleFrame.maxX - width)
        let y = clamp(centeredY, min: visibleFrame.minY, max: visibleFrame.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        guard minValue <= maxValue else { return minValue }
        return min(max(value, minValue), maxValue)
    }
}
