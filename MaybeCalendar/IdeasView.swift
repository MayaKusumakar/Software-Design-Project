import SwiftUI

struct IdeasView: View {
    @Environment(Store.self) private var store
    @Binding var selectedDay: Date
    @Binding var focusDate: Date?
    @Binding var tab: AppTab

    @State private var newIdea = ""
    @State private var editor: EditorRequest?

    private var trimmed: String { newIdea.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Something to do when you're free", text: $newIdea)
                            .submitLabel(.done)
                            .onSubmit(add)
                        Button("Add", action: add)
                            .disabled(trimmed.isEmpty)
                    }
                } footer: {
                    Text("Ideas don't have a date. When you find time, tap Schedule to put one on your calendar as a potential plan.")
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
                            Text(idea.title)
                            Spacer()
                            Button("Schedule") {
                                editor = .new(
                                    day: selectedDay,
                                    hour: EditorRequest.suggestedHour(for: selectedDay),
                                    title: idea.title,
                                    status: .potential,
                                    ideaID: idea.id
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
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
        }
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        store.addIdea(trimmed)
        newIdea = ""
    }
}
