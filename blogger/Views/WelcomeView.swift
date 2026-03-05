import SwiftUI

struct WelcomeView: View {
    var isDragTargeted: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isDragTargeted ? "photo.badge.plus" : "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(isDragTargeted ? Color.accentColor : Color.secondary)
                .animation(.easeInOut(duration: 0.15), value: isDragTargeted)

            Text("Blogger")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(isDragTargeted
                 ? "Drop photos to start a new post"
                 : "Drag photos here from Finder to create a new post")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)
                .animation(.easeInOut(duration: 0.15), value: isDragTargeted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isDragTargeted ? Color.accentColor : Color.clear,
                    style: StrokeStyle(lineWidth: 3, dash: [10])
                )
                .padding(12)
                .animation(.easeInOut(duration: 0.15), value: isDragTargeted)
        )
    }
}
