import SwiftUI
import Photos

struct DateRangePickerView: View {
    @Binding var isPresented: Bool
    let onConfirm: (Date, Date) -> Void

    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

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
                    Button("Load Photos") {
                        isPresented = false
                        // Set endDate to include the full selected day
                        onConfirm(startDate, endDate)
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
                    Text("Folio needs access to your photo library to curate photos by date.")
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
