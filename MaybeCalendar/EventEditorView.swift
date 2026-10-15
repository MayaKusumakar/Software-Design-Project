import SwiftUI

/// What the event editor sheet should open with.
struct EditorRequest: Identifiable {
    let id = UUID()
    var event: PlanEvent
    var isNew: Bool
    /// Set when scheduling an idea, so the idea can be removed from the list on save.
    var ideaID: Idea.ID?

    static func edit(_ event: PlanEvent) -> EditorRequest {
        EditorRequest(event: event, isNew: false)
    }

    static func new(day: Date, hour: Int, title: String = "", status: PlanStatus = .confirmed, ideaID: Idea.ID? = nil) -> EditorRequest {
        let cal = Calendar.current
        let start = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        let end = hour < 23
            ? cal.date(byAdding: .hour, value: 1, to: start)!
            : cal.date(bySettingHour: 23, minute: 59, second: 0, of: day)!
        return EditorRequest(event: PlanEvent(title: title, start: start, end: end, status: status), isNew: true, ideaID: ideaID)
    }

    /// The next full hour if `day` is today, otherwise 9am.
    static func suggestedHour(for day: Date) -> Int {
        guard Calendar.current.isDateInToday(day) else { return 9 }
        return min(Calendar.current.component(.hour, from: .now) + 1, 23)
    }
}

struct EventEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let request: EditorRequest
    var onSaved: (Date) -> Void = { _ in }

    @State private var title: String
    @State private var day: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var status: PlanStatus
    @State private var notes: String
    @State private var keepIdea = false
    @State private var confirmingDelete = false

    init(request: EditorRequest, onSaved: @escaping (Date) -> Void = { _ in }) {
        self.request = request
        self.onSaved = onSaved
        _title = State(initialValue: request.event.title)
        _day = State(initialValue: request.event.start)
        _startTime = State(initialValue: request.event.start)
        _endTime = State(initialValue: request.event.end)
        _status = State(initialValue: request.event.status)
        _notes = State(initialValue: request.event.notes)
    }

    private var start: Date { combine(day, startTime) }
    private var end: Date { combine(day, endTime) }
    private var timesValid: Bool { end > start }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && timesValid }

    private var navTitle: String {
        if !request.isNew { return "Edit Event" }
        return request.ideaID != nil ? "Schedule Idea" : "New Event"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                }

                Section {
                    DatePicker("Date", selection: $day, displayedComponents: .date)
                    DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $endTime, displayedComponents: .hourAndMinute)
                    if !timesValid {
                        Text("End time must be after start time.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Picker("Status", selection: $status) {
                        ForEach(PlanStatus.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Status")
                } footer: {
                    Text(status == .potential
                         ? "Potential plans appear as dashed blocks you can hide. Tap + on the block to commit."
                         : "Confirmed plans always show on your calendar.")
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                if request.ideaID != nil {
                    Section {
                        Toggle("Keep in my ideas list", isOn: $keepIdea)
                    }
                }

                if !request.isNew {
                    Section {
                        Button("Delete Event", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .confirmationDialog("Delete this event?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.deleteEvent(request.event.id)
                    dismiss()
                }
            }
        }
    }

    private func save() {
        var event = request.event
        event.title = title.trimmingCharacters(in: .whitespaces)
        event.start = start
        event.end = end
        event.status = status
        event.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        store.upsert(event)
        if let ideaID = request.ideaID, !keepIdea {
            store.removeIdea(ideaID)
        }
        onSaved(event.start)
        dismiss()
    }

    /// The calendar date of `day` with the hour and minute of `time`.
    private func combine(_ day: Date, _ time: Date) -> Date {
        let cal = Calendar.current
        let t = cal.dateComponents([.hour, .minute], from: time)
        return cal.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: 0, of: day) ?? day
    }
}
