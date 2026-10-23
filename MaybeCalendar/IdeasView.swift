import SwiftUI

struct IdeasView: View {
    @Environment(Store.self) private var store
    @Binding var selectedDay: Date
    @Binding var focusDate: Date?
    @Binding var tab: AppTab

    @State private var newIdea = ""
    @State private var editor: EditorRequest?
    @State private var ideaEditor: IdeaEditorRequest?
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
                    Text("Ideas don't have a date. The calendar suggests them when you have free time that fits. Tap an idea to set how long it takes, when it works best, and a category.")
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
                        .onTapGesture { ideaEditor = .edit(idea) }
                        .accessibilityAction(named: "Edit") { ideaEditor = .edit(idea) }
                    }
                    .onDelete { store.removeIdeas(at: $0) }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Ideas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { ideaEditor = .new } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New idea with details")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { newIdeaFocused = false }
                }
            }
            .sheet(item: $editor) { request in
                EventEditorView(request: request) { savedDate in
                    selectedDay = savedDate
                    focusDate = savedDate
                    tab = .calendar
                }
            }
            .sheet(item: $ideaEditor) { request in
                IdeaEditorView(request: request)
            }
        }
    }

    /// "1 hr · Evening · Outdoors · Regular"
    private func details(for idea: Idea) -> String {
        var parts = [idea.minutes.map { durationText(minutes: $0) } ?? "About \(durationText(minutes: Idea.defaultMinutes))"]
        if let timing = idea.timingText { parts.append(timing) }
        if let category = idea.category, !category.isEmpty { parts.append(category) }
        if idea.repeats == true { parts.append("Regular") }
        return parts.joined(separator: " · ")
    }

    /// Opens the editor at the first free time on the selected day where the idea fits.
    private func schedule(_ idea: Idea) {
        let start = SuggestionEngine.firstFit(for: idea, on: selectedDay, events: store.events, now: .now)
            ?? Calendar.current.date(bySettingHour: EditorRequest.suggestedHour(for: selectedDay), minute: 0, second: 0, of: selectedDay)!
        editor = .new(start: start, minutes: idea.effectiveMinutes, title: idea.title, status: .potential, ideaID: idea.id)
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        store.addIdea(trimmed)
        newIdea = ""
    }
}
