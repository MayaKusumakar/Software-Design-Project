import SwiftUI

struct IdeasView: View {
    @Environment(Store.self) private var store
    @Binding var selectedDay: Date
    @Binding var focusDate: Date?
    @Binding var tab: AppTab
    /// Set from the calendar's "Add an idea" button to start typing right away.
    @Binding var focusNewIdea: Bool

    @State private var newIdea = ""
    @State private var editor: EditorRequest?
    @State private var ideaToEdit: Idea?
    @FocusState private var newIdeaFocused: Bool

    private var trimmed: String { newIdea.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Something to do when you're free", text: $newIdea)
                            .focused($newIdeaFocused)
                            .submitLabel(.done)
                            .onSubmit(add)
                        Button("Add", action: add)
                            .disabled(trimmed.isEmpty)
                    }
                } footer: {
                    Text("Ideas don't have a date. They show up as suggestions when you have free time that fits, or tap Schedule to plan one yourself. Tap an idea to say how long it takes.")
                }

                Section("Your ideas") {
                    if store.ideas.isEmpty {
                        Text("No ideas yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.ideas) { idea in
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(idea.title)
                                Text(details(for: idea))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Schedule") { schedule(idea) }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { ideaToEdit = idea }
                        .accessibilityAction(named: "Edit") { ideaToEdit = idea }
                    }
                    .onDelete { store.removeIdeas(at: $0) }
                }
            }
            .navigationTitle("Ideas")
            .sheet(item: $editor) { request in
                EventEditorView(request: request) { savedDate in
                    selectedDay = savedDate
                    focusDate = savedDate
                    tab = .calendar
                }
            }
            .sheet(item: $ideaToEdit) { idea in
                IdeaEditorView(idea: idea)
            }
            .task(id: focusNewIdea) {
                guard focusNewIdea else { return }
                try? await Task.sleep(for: .milliseconds(350))
                newIdeaFocused = true
                focusNewIdea = false
            }
        }
    }

    /// "About 1 hr · Evening · Regular"
    private func details(for idea: Idea) -> String {
        var parts = [idea.minutes.map { durationText(minutes: $0) } ?? "About \(durationText(minutes: Idea.defaultMinutes))"]
        if let best = idea.bestTime, best != .any { parts.append(best.label) }
        if idea.repeats == true { parts.append("Regular") }
        return parts.joined(separator: " · ")
    }

    /// Opens the editor at the first free time on the selected day where the idea fits.
    private func schedule(_ idea: Idea) {
        if let start = SuggestionEngine.firstFit(for: idea, on: selectedDay, events: store.events, now: .now) {
            editor = .new(start: start, minutes: idea.effectiveMinutes, title: idea.title, status: .potential, ideaID: idea.id)
        } else {
            let start = Calendar.current.date(bySettingHour: EditorRequest.suggestedHour(for: selectedDay), minute: 0, second: 0, of: selectedDay)!
            editor = .new(start: start, minutes: idea.effectiveMinutes, title: idea.title, status: .potential, ideaID: idea.id)
        }
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        store.addIdea(trimmed)
        newIdea = ""
    }
}
