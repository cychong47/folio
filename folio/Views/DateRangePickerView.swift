import SwiftUI
import Photos

struct DateRangePickerPresentation: Identifiable {
    let id = UUID()
    let recentPosts: [PostSummary]
}

struct DateRangePickerView: View {
    @Binding var isPresented: Bool
    let confirmLabel: String
    let recentPosts: [PostSummary]
    let recentBrowseRanges: [RecentPhotoBrowseRange]
    let onConfirm: (Date, Date, TimeZone?) -> Void

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var startText: String
    @State private var endText: String
    @State private var noLocationTimeZoneMode: NoLocationTimeZoneMode
    @State private var noLocationOffsetSeconds: Int
    @State private var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    private enum NoLocationTimeZoneMode: String, CaseIterable, Identifiable {
        case mac
        case manual

        var id: String { rawValue }
    }

    init(
        isPresented: Binding<Bool>,
        initialStartDate: Date? = nil,
        initialEndDate: Date? = nil,
        initialNoLocationTimeZone: TimeZone? = nil,
        recentPosts: [PostSummary] = [],
        recentBrowseRanges: [RecentPhotoBrowseRange] = PhotoBrowseHistoryStore().recentRanges(),
        confirmLabel: String = "Load Photos",
        onConfirm: @escaping (Date, Date, TimeZone?) -> Void
    ) {
        let defaultEndDate = Calendar.current.startOfDay(for: Date())
        let defaultStartDate = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        )
        let initialStart = Calendar.current.startOfDay(for: initialStartDate ?? defaultStartDate)
        let initialEnd = Calendar.current.startOfDay(for: initialEndDate ?? defaultEndDate)
        _isPresented = isPresented
        _startDate = State(initialValue: initialStart)
        _endDate = State(initialValue: initialEnd)
        _startText = State(initialValue: PhotoDateRangeSelection.string(from: initialStart))
        _endText = State(initialValue: PhotoDateRangeSelection.string(from: initialEnd))
        _noLocationTimeZoneMode = State(initialValue: initialNoLocationTimeZone == nil ? .mac : .manual)
        _noLocationOffsetSeconds = State(
            initialValue: initialNoLocationTimeZone?.secondsFromGMT() ?? TimeZone.current.secondsFromGMT()
        )
        self.recentPosts = Array(recentPosts.prefix(5))
        self.recentBrowseRanges = Array(recentBrowseRanges.prefix(5))
        self.confirmLabel = confirmLabel
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Select Photo Date Range")
                .font(.headline)

            if authStatus == .authorized || authStatus == .limited {
                if hasQuickPicks {
                    quickPicksSection
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("From")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: Binding(
                            get: { startDate },
                            set: { updateStartDate($0) }
                        ), in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                        TextField(PhotoDateRangeSelection.formatHint, text: $startText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                            .onChange(of: startText) { newValue in
                                syncStartText(newValue)
                            }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("To")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: Binding(
                            get: { endDate },
                            set: { updateEndDate($0) }
                        ), in: startDate...Date(), displayedComponents: .date)
                            .labelsHidden()
                        TextField(PhotoDateRangeSelection.formatHint, text: $endText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                            .onChange(of: endText) { newValue in
                                syncEndText(newValue)
                            }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Selected: \(selectedRangeLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                VStack(alignment: .leading, spacing: 10) {
                    Text("No-location timezone")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("No-location camera timezone", selection: $noLocationTimeZoneMode) {
                        Text("Use Mac timezone").tag(NoLocationTimeZoneMode.mac)
                        Text("Manual UTC offset").tag(NoLocationTimeZoneMode.manual)
                    }
                    .pickerStyle(.segmented)

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("UTC offset")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 78, alignment: .leading)

                        Picker("UTC offset", selection: $noLocationOffsetSeconds) {
                            ForEach(Self.noLocationOffsetOptions, id: \.self) { seconds in
                                Text(Self.offsetLabel(seconds)).tag(seconds)
                            }
                        }
                        .frame(width: 150)
                        .disabled(noLocationTimeZoneMode != .manual)

                        Spacer()
                    }

                    Text(noLocationTimeZoneHelp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))

                HStack {
                    Spacer()
                    Button("Cancel") { isPresented = false }
                    Button(confirmLabel) {
                        guard let range = selectedRange else { return }
                        isPresented = false
                        PhotoBrowseHistoryStore().record(
                            startDate: range.start,
                            endDate: range.end,
                            noLocationTimeZone: selectedNoLocationTimeZone
                        )
                        onConfirm(range.start, range.end, selectedNoLocationTimeZone)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedRange == nil)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.circle")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("Photos Access Required")
                        .font(.headline)
                    Text("Photolog needs access to your photo library to curate photos by date.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Grant Access") {
                        Task {
                            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                            authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                HStack {
                    Spacer()
                    Button("Cancel") { isPresented = false }
                }
            }
        }
        .padding(24)
        .frame(width: hasQuickPicks ? 720 : 520)
        .frame(minHeight: hasQuickPicks ? 500 : 360)
        .onAppear {
            authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        }
    }

    private var hasQuickPicks: Bool {
        !recentPosts.isEmpty || !recentBrowseRanges.isEmpty
    }

    private var quickPicksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Picks")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 18) {
                quickPickColumn(title: "Recent Posts") {
                    if recentPosts.isEmpty {
                        quickPickPlaceholder("No recent posts")
                    } else {
                        ForEach(recentPosts) { post in
                            quickPickRow(
                                title: post.title,
                                trailing: Self.postDateLabel(post.date)
                            ) {
                                applyPostDate(post.date)
                            }
                        }
                    }
                }

                quickPickColumn(title: "Recent Photo Browses") {
                    if recentBrowseRanges.isEmpty {
                        quickPickPlaceholder("No recent ranges")
                    } else {
                        ForEach(recentBrowseRanges) { range in
                            quickPickRow(
                                title: Self.rangeLabel(start: range.startDate, end: range.endDate),
                                trailing: range.noLocationOffsetSeconds.map(Self.offsetLabel) ?? "Mac timezone"
                            ) {
                                applyBrowseRange(range)
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
    }

    private func quickPickColumn<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func quickPickPlaceholder(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
    }

    private func quickPickRow(title: String, trailing: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                Text(trailing)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minHeight: 26)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help("Use this date range")
    }

    private var selectedRangeLabel: String {
        guard let range = selectedRange else {
            return "Invalid date. Use \(PhotoDateRangeSelection.formatHint)."
        }
        let calendar = Calendar.current
        let start = range.start
        let end = range.end
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = calendar.timeZone
        if calendar.isDate(start, inSameDayAs: end) {
            return formatter.string(from: start)
        }
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private var selectedRange: (start: Date, end: Date)? {
        PhotoDateRangeSelection.range(startText: startText, endText: endText)
    }

    private var selectedNoLocationTimeZone: TimeZone? {
        guard noLocationTimeZoneMode == .manual else { return nil }
        return TimeZone(secondsFromGMT: noLocationOffsetSeconds)
    }

    private var noLocationTimeZoneHelp: String {
        if noLocationTimeZoneMode == .manual {
            return "No-GPS photos without an EXIF timezone use \(Self.offsetLabel(noLocationOffsetSeconds))."
        }
        return "No-GPS photos without an EXIF timezone use this Mac's timezone."
    }

    private static let noLocationOffsetOptions = Array(stride(
        from: -12 * 3600,
        through: 14 * 3600,
        by: 30 * 60
    ))

    private static func offsetLabel(_ seconds: Int) -> String {
        let sign = seconds >= 0 ? "+" : "-"
        let absoluteSeconds = abs(seconds)
        let hours = absoluteSeconds / 3600
        let minutes = (absoluteSeconds % 3600) / 60
        return String(format: "UTC%@%02d:%02d", sign, hours, minutes)
    }

    private static func postDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func rangeLabel(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        if Calendar.current.isDate(start, inSameDayAs: end) {
            return formatter.string(from: start)
        }
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private func applyPostDate(_ date: Date) {
        let normalized = Calendar.current.startOfDay(for: date)
        updateStartDate(normalized)
        updateEndDate(normalized)
    }

    private func applyBrowseRange(_ range: RecentPhotoBrowseRange) {
        updateStartDate(range.startDate)
        updateEndDate(range.endDate)
        if let offset = range.noLocationOffsetSeconds {
            noLocationTimeZoneMode = .manual
            noLocationOffsetSeconds = offset
        } else {
            noLocationTimeZoneMode = .mac
        }
    }

    private func updateStartDate(_ date: Date) {
        let normalized = Calendar.current.startOfDay(for: date)
        startDate = normalized
        startText = PhotoDateRangeSelection.string(from: normalized)
        if endDate < normalized {
            updateEndDate(normalized)
        }
    }

    private func updateEndDate(_ date: Date) {
        let normalized = Calendar.current.startOfDay(for: date)
        endDate = normalized
        endText = PhotoDateRangeSelection.string(from: normalized)
    }

    private func syncStartText(_ text: String) {
        guard let date = PhotoDateRangeSelection.date(from: text) else { return }
        startDate = date
        if let end = PhotoDateRangeSelection.date(from: endText), end < date {
            endDate = date
            endText = PhotoDateRangeSelection.string(from: date)
        }
    }

    private func syncEndText(_ text: String) {
        guard let date = PhotoDateRangeSelection.date(from: text) else { return }
        endDate = date
    }
}
