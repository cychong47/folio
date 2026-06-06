import SwiftUI
import Photos

struct DateRangePickerView: View {
    @Binding var isPresented: Bool
    let confirmLabel: String
    let onConfirm: (Date, Date) -> Void

    @State private var startDate: Date
    @State private var endDate: Date
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
        _isPresented = isPresented
        _startDate = State(initialValue: Calendar.current.startOfDay(for: initialStartDate ?? defaultStartDate))
        _endDate = State(initialValue: Calendar.current.startOfDay(for: initialEndDate ?? defaultEndDate))
        self.confirmLabel = confirmLabel
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Select Photo Date Range")
                .font(.headline)

            if authStatus == .authorized || authStatus == .limited {
                Form {
                    DatePicker("From", selection: $startDate, in: ...Date(), displayedComponents: .date)
                    DatePicker("To", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                }
                .formStyle(.grouped)

                HStack {
                    Spacer()
                    Button("Cancel") { isPresented = false }
                    Button(confirmLabel) {
                        isPresented = false
                        onConfirm(
                            Calendar.current.startOfDay(for: startDate),
                            Calendar.current.startOfDay(for: endDate)
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(endDate < startDate)
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
        .frame(width: 360)
        .onAppear {
            authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        }
    }
}
