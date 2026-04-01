import SwiftUI

// Add new entries here each release. All versions newer than lastSeenVersion are shown.
private let releaseNotes: [(version: String, bullets: [String])] = [
    ("1.8.1", [
        "Scan Posts now collects tags — tag suggestions appear in the post editor menu",
        "Fix: Categories and Series sections no longer stay empty after a scan",
    ]),
    ("1.8", [
        "What's New sheet — shown automatically on first launch of each new version",
    ]),
    ("1.7", [
        "Renamed from Blogger to Folio",
        "GitHub Pages release notes site — auto-generated from the changelog on every CI push",
        "Settings → Updates: Release Notes link",
    ]),
    ("1.6", [
        "Strip GPS & device EXIF metadata on export — Privacy toggle in Settings → Image Export (on by default)",
    ]),
    ("1.5", [
        "Cap exported image dimensions per profile — max long-edge setting in Settings → Image Export",
    ]),
]

struct WhatsNewView: View {
    let currentVersion: String
    let sinceVersion: String
    let onDismiss: () -> Void

    private var visibleSections: [(version: String, bullets: [String])] {
        releaseNotes.filter { isNewer($0.version, than: sinceVersion) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What's New")
                .font(.system(size: 22, weight: .bold))
                .padding(.bottom, 4)
            Text("Version \(currentVersion)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(visibleSections, id: \.version) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            if visibleSections.count > 1 {
                                Text("v\(section.version)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.accent)
                            }
                            ForEach(section.bullets, id: \.self) { bullet in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(Theme.accent)
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 7)
                                    Text(bullet)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 260)

            Spacer(minLength: 24)

            HStack {
                Spacer()
                Button("Got it") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 380)
        .background(Theme.background)
    }

    private func isNewer(_ version: String, than other: String) -> Bool {
        let a = version.split(separator: ".").compactMap { Int($0) }
        let b = other.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(a.count, b.count) {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av != bv { return av > bv }
        }
        return false
    }
}
