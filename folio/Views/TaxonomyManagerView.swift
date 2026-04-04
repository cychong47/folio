import SwiftUI

struct TaxonomyManagerView: View {
    let contentPath: String
    @EnvironmentObject var settings: AppSettings

    @State private var terms: [TaxonomyKind: [TaxonomyTerm]] = [:]
    @State private var isLoading = false
    @State private var statusMessage: String? = nil
    @State private var selectedKind: TaxonomyKind = .categories

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Taxonomy Manager")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.7).padding(.trailing, 4)
                }
                Button("Refresh") { loadTerms() }
                    .disabled(isLoading)
                Button("Done") { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // Tab picker
            Picker("", selection: $selectedKind) {
                ForEach(TaxonomyKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            // Term list
            let currentTerms = terms[selectedKind] ?? []
            if currentTerms.isEmpty {
                VStack {
                    Spacer()
                    Text(isLoading ? "Scanning…" : "No \(selectedKind.displayName.lowercased()) found.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                    Spacer()
                }
            } else {
                List(currentTerms) { term in
                    TaxonomyTermRow(
                        term: term,
                        kind: selectedKind,
                        otherTerms: currentTerms.filter { $0.id != term.id },
                        contentPath: contentPath,
                        onComplete: { message in
                            statusMessage = message
                            loadTerms()
                        }
                    )
                }
                .listStyle(.plain)
            }

            // Status bar
            if let msg = statusMessage {
                Divider()
                HStack {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
        }
        .frame(width: 520, height: 420)
        .onAppear { loadTerms() }
    }

    private func loadTerms() {
        isLoading = true
        statusMessage = nil
        let path = contentPath
        DispatchQueue.global(qos: .userInitiated).async {
            let result = TaxonomyManager.scan(contentPath: path)
            DispatchQueue.main.async {
                terms = result
                isLoading = false
            }
        }
    }
}

private struct TaxonomyTermRow: View {
    let term: TaxonomyTerm
    let kind: TaxonomyKind
    let otherTerms: [TaxonomyTerm]
    let contentPath: String
    let onComplete: (String) -> Void

    @EnvironmentObject var settings: AppSettings
    @State private var showRename = false
    @State private var showMerge = false
    @State private var newName = ""
    @State private var mergeTarget: TaxonomyTerm? = nil

    var body: some View {
        HStack {
            Text(term.name)
                .font(.callout)
            Spacer()
            Text("\(term.postCount) post\(term.postCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Theme.chipBg, in: Capsule())
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Rename \"\(term.name)\"…") {
                newName = term.name
                showRename = true
            }
            if !otherTerms.isEmpty {
                Button("Merge into…") {
                    mergeTarget = otherTerms.first
                    showMerge = true
                }
            }
        }
        .sheet(isPresented: $showRename) {
            RenameSheet(
                original: term.name,
                newName: $newName,
                onConfirm: { performRename() }
            )
        }
        .sheet(isPresented: $showMerge) {
            MergeSheet(
                source: term.name,
                target: $mergeTarget,
                options: otherTerms,
                onConfirm: { performMerge() }
            )
        }
    }

    private func performRename() {
        let old = term.name
        let new = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !new.isEmpty, new != old else { return }
        let path = contentPath
        let k = kind
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let count = try TaxonomyManager.rename(from: old, to: new, kind: k, in: path)
                DispatchQueue.main.async {
                    settings.updateActiveProfile { profile in
                        switch k {
                        case .categories:
                            profile.knownCategories = profile.knownCategories.map { $0 == old ? new : $0 }
                        case .tags:
                            profile.knownTags = profile.knownTags.map { $0 == old ? new : $0 }
                        case .series:
                            profile.knownSeries = profile.knownSeries.map { $0 == old ? new : $0 }
                        }
                    }
                    onComplete("Renamed \"\(old)\" → \"\(new)\" in \(count) file\(count == 1 ? "" : "s")")
                }
            } catch {
                DispatchQueue.main.async {
                    onComplete("Error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func performMerge() {
        guard let target = mergeTarget else { return }
        let source = term.name
        let targetName = target.name
        let path = contentPath
        let k = kind
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let count = try TaxonomyManager.merge(source: source, into: targetName, kind: k, in: path)
                DispatchQueue.main.async {
                    settings.updateActiveProfile { profile in
                        switch k {
                        case .categories:
                            profile.knownCategories = profile.knownCategories.filter { $0 != source }
                        case .tags:
                            profile.knownTags = profile.knownTags.filter { $0 != source }
                        case .series:
                            profile.knownSeries = profile.knownSeries.filter { $0 != source }
                        }
                    }
                    onComplete("Merged \"\(source)\" into \"\(targetName)\" across \(count) file\(count == 1 ? "" : "s")")
                }
            } catch {
                DispatchQueue.main.async {
                    onComplete("Error: \(error.localizedDescription)")
                }
            }
        }
    }
}

private struct RenameSheet: View {
    let original: String
    @Binding var newName: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename \"\(original)\"")
                .font(.headline)
            TextField("New name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { confirm() }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Rename") { confirm() }
                    .keyboardShortcut(.return)
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
    }

    private func confirm() {
        dismiss()
        onConfirm()
    }
}

private struct MergeSheet: View {
    let source: String
    @Binding var target: TaxonomyTerm?
    let options: [TaxonomyTerm]
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Merge \"\(source)\" into…")
                .font(.headline)
            Picker("Target", selection: $target) {
                ForEach(options) { term in
                    Text(term.name).tag(Optional(term))
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            Text("All posts tagged \"\(source)\" will be updated to \"\(target?.name ?? "")\". This cannot be undone.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Merge") { confirm() }
                    .keyboardShortcut(.return)
                    .disabled(target == nil)
            }
        }
        .padding(24)
        .frame(width: 320)
    }

    private func confirm() {
        dismiss()
        onConfirm()
    }
}
