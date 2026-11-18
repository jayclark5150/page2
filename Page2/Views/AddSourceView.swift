import SwiftUI
import SwiftData

/// A form to add a custom outlet. Checks the feed URL is live before saving.
struct AddSourceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var urlString = ""
    @State private var siteString = ""
    @State private var bias: Bias = .center
    @State private var status: FeedValidator.Status = .idle

    var body: some View {
        Form {
            Section("Outlet") {
                TextField("Name", text: $name)
                TextField("Feed URL", text: $urlString, axis: .vertical)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .onChange(of: urlString) { status = .idle }
                Picker("Bias", selection: $bias) {
                    ForEach(Bias.allCases) { Text($0.label).tag($0) }
                }
            }

            Section {
                Button(action: check) {
                    HStack {
                        Text("Check feed")
                        if status == .checking {
                            Spacer()
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                .disabled(urlString.isEmpty || status == .checking)

                statusRow
            } footer: {
                Text("Checking confirms the URL returns a real RSS or Atom feed.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Add Source")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add", action: save).disabled(!canSave)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        #if os(macOS)
        .frame(width: 420, height: 320)
        #endif
    }

    @ViewBuilder
    private var statusRow: some View {
        switch status {
        case .idle, .checking:
            EmptyView()
        case .valid(let count):
            Label("Feed looks good, found \(count) articles", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        case .invalid(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.callout)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !urlString.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func check() {
        status = .checking
        let value = urlString
        Task {
            let result = await FeedValidator.check(value)
            await MainActor.run { status = result }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingSlugs = (try? modelContext.fetch(FetchDescriptor<Source>()))?
            .map(\.slug) ?? []
        let slug = Slug.unique(Slug.make(from: trimmedName), taken: Set(existingSlugs))

        let source = Source(
            slug: slug,
            name: trimmedName,
            feedURLString: urlString.trimmingCharacters(in: .whitespacesAndNewlines),
            siteURLString: siteString.trimmingCharacters(in: .whitespacesAndNewlines),
            bias: bias,
            isUserAdded: true
        )
        modelContext.insert(source)
        try? modelContext.save()
        dismiss()
    }
}
