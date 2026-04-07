import SwiftUI

struct UpdatePopupView: View {
    @ObservedObject var checker: UpdateChecker
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Check for Updates")
                .font(.headline)

            statusView

            HStack {
                Spacer()
                Button("Close") { onClose() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 340)
    }

    @ViewBuilder
    private var statusView: some View {
        switch checker.state {
        case .idle, .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking for updates…")
                    .foregroundStyle(.secondary)
            }

        case .upToDate:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Folio is up to date.")
            }

        case .available(let tagName, let downloadURL):
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Theme.accent)
                    Text("Version \(tagName) is available")
                        .fontWeight(.medium)
                }
                if downloadURL.isEmpty {
                    Text("No download asset is attached yet. Check the GitHub releases page.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Button("Download Update") {
                        checker.downloadAndInstall(downloadURL: downloadURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                }
            }

        case .downloading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Downloading update…")
                    .foregroundStyle(.secondary)
            }

        case .readyToInstall(let newAppURL):
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                    Text("Update ready to install")
                        .fontWeight(.medium)
                }
                Text("Folio will quit, replace itself with the new version, and reopen automatically.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button("Quit & Install") {
                        onClose()
                        checker.installAndRelaunch(from: newAppURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    Button("Later") { onClose() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }

        case .error(let message):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Update check failed")
                }
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try Again") { checker.checkForUpdates() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}
