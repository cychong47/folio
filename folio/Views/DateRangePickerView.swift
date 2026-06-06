import SwiftUI
import Photos

struct DateRangePickerView: View {
    @Binding var isPresented: Bool
    let confirmLabel: String
    let onConfirm: (Date, Date) -> Void

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var startText: String
    @State private var endText: String
    @State private var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    init(
        isPresented: Binding<Bool>,
        initialStartDate: Date? = nil,
        initialEndDate: Date? = nil,
        confirmLabel: String = "Load Photos",
        onConfirm: @escaping (Date, Date) -> Void
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
        self.confirmLabel = confirmLabel
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Select Photo Date Range")
                .font(.headline)

            if authStatus == .authorized || authStatus == .limited {
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

                HStack {
                    Spacer()
                    Button("Cancel") { isPresented = false }
                    Button(confirmLabel) {
                        guard let range = selectedRange else { return }
                        isPresented = false
                        onConfirm(range.start, range.end)
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
        .frame(width: 520)
        .onAppear {
            authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        }
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
