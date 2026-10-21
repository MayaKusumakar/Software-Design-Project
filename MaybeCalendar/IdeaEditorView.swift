import SwiftUI

/// View or edit one idea. Everything except the title is optional.
struct IdeaEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let idea: Idea

    @State private var title: String
    @State private var minutes: Int?
    @State private var bestTime: BestTime
    @State private var repeats: Bool

    private static let lengths = [15, 30, 45, 60, 90, 120, 180, 240]

    init(idea: Idea) {
        self.idea = idea
        _title = State(initialValue: idea.title)
        _minutes = State(initialValue: idea.minutes)
        _bestTime = State(initialValue: idea.bestTime ?? .any)
        _repeats = State(initialValue: idea.repeats ?? false)
    }

    private var trimmed: String { title.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Idea", text: $title)
                        .submitLabel(.done)
                }

                Section {
                    Picker("Takes about", selection: $minutes) {
                        Text("Not sure").tag(Int?.none)
                        ForEach(Self.lengths, id: \.self) { length in
                            Text(durationText(minutes: length)).tag(Int?.some(length))
                        }
                    }
                    Picker("Best time", selection: $bestTime) {
                        ForEach(BestTime.allCases) { Text($0.label).tag($0) }
                    }
                } footer: {
                    Text("Used to suggest this when you have free time that fits. If you're not sure how long it takes, we'll plan for about \(durationText(minutes: Idea.defaultMinutes)).")
                }

                Section {
                    Toggle("I do this regularly", isOn: $repeats)
                } footer: {
                    Text("Regular ideas stay in your list after you schedule them.")
                }

                Section {
                    Button("Delete Idea", role: .destructive) {
                        store.removeIdea(idea.id)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(trimmed.isEmpty)
                }
            }
        }
    }

    private func save() {
        var updated = idea
        updated.title = trimmed
        updated.minutes = minutes
        updated.bestTime = bestTime == .any ? nil : bestTime
        updated.repeats = repeats
        store.updateIdea(updated)
        dismiss()
    }
}
