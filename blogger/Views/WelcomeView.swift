import SwiftUI

struct WelcomeView: View {
    var isDragTargeted: Bool = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 18) {
                // Icon in a soft circle, like Things' onboarding
                ZStack {
                    Circle()
                        .fill(isDragTargeted ? Theme.accent.opacity(0.12) : Theme.panel)
                        .frame(width: 100, height: 100)
                    Image(systemName: isDragTargeted ? "photo.badge.plus" : "photo.on.rectangle.angled")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(isDragTargeted ? Theme.accent : Color.secondary)
                }
                .animation(.easeInOut(duration: 0.15), value: isDragTargeted)

                VStack(spacing: 6) {
                    Text("Blogger")
                        .font(.title2.weight(.semibold))
                    Text(isDragTargeted
                         ? "Drop to start a new post"
                         : "Drag photos here to create a Hugo post")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
                .animation(.easeInOut(duration: 0.15), value: isDragTargeted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isDragTargeted ? Theme.accent : Color.clear,
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .padding(20)
                    .animation(.easeInOut(duration: 0.15), value: isDragTargeted)
            )
        }
    }
}
