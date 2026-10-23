import SwiftUI

/// What the event editor sheet should open with.
struct EditorRequest: Identifiable {
    let id = UUID()
    var event: PlanEvent
    var isNew: Bool
    /// Set when scheduling an idea, so the idea can be removed from the list on save.
    var ideaID: Idea.ID?
    /// Set when adding a suggestion, so the choice is remembered once it's saved.
    var suggestionKey: String?

    static func edit(_ event: PlanEvent) -> EditorRequest {
        EditorRequest(event: event, isNew: false)
    }

    static func new(day: Date, hour: Int, title: String = "", status: PlanStatus = .confirmed, ideaID: Idea.ID? = nil) -> EditorRequest {
        new(day: day, minute: hour * 60, title: title, status: status, ideaID: ideaID)
    }

    /// A new plan starting `minute` minutes after midnight on `day`.
    static func new(day: Date, minute: Int, title: String = "", status: PlanStatus = .confirmed, ideaID: Idea.ID? = nil) -> EditorRequest {
        let start = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)!
        return new(start: start, minutes: 60, title: title, status: status, ideaID: ideaID)
    }

    static func new(start: Date, minutes: Int, title: String = "", status: PlanStatus = .confirmed, ideaID: Idea.ID? = nil) -> EditorRequest {
        // End by midnight at the latest, since the editor has a single date.
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: start))!
        let end = min(start.addingTimeInterval(TimeInterval(minutes * 60)), midnight)
        var event = PlanEvent(title: title, start: start, end: end, status: status)
        event.ideaID = ideaID
        return EditorRequest(event: event, isNew: true, ideaID: ideaID)
    }

    /// Prefilled from a suggestion as a potential plan, which the user can still change.
    static func suggested(_ suggestion: Suggestion) -> EditorRequest {
        var request = new(start: suggestion.start, minutes: suggestion.minutes, title: suggestion.title,
                          status: .potential, ideaID: suggestion.ideaID)
        request.event.freeTime = true
        request.suggestionKey = suggestion.key
        return request
    }

    /// The next full hour if `day` is today, otherwise 9am.
    static func suggestedHour(for day: Date) -> Int {
        guard Calendar.current.isDateInToday(day) else { return 9 }
        return min(Calendar.current.component(.hour, from: .now) + 1, 23)
    }
}

/// Turns the editor's separate date and time pickers into real start and end dates.
enum PlanTime {
    /// The calendar date of `day` with the hour and minute of `time`.
    static func combine(_ day: Date, _ time: Date, calendar: Calendar = .current) -> Date {
        let t = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: 0, of: day) ?? day
    }

    /// An end time of 12:00 AM after a later start means midnight at the end of that day.
    static func end(day: Date, start: Date, endTime: Date, calendar: Calendar = .current) -> Date {
        let end = combine(day, endTime, calendar: calendar)
        let t = calendar.dateComponents([.hour, .minute], from: endTime)
        if end <= start, t.hour == 0, t.minute == 0 {
            return calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }
        return end
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
    @FocusState private var titleFocused: Bool

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

    private var start: Date { PlanTime.combine(day, startTime) }
    private var end: Date { PlanTime.end(day: day, start: start, endTime: endTime) }
    private var timesValid: Bool { end > start }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && timesValid }

    /// Plans that came from an idea or are only a maybe can go back to the Ideas list.
    private var canMoveBackToIdeas: Bool {
        !request.isNew && (request.event.ideaID != nil || request.event.status == .potential)
    }

    /// Other plans at the same time. Overlaps are allowed (to compare options), but worth a heads-up.
    private var overlapping: [PlanEvent] {
        store.events
            .filter { $0.id != request.event.id && $0.start < end && $0.end > start }
            .sorted { $0.start < $1.start }
    }

    private var overlapWarning: String? {
        guard timesValid, let first = overlapping.first else { return nil }
        let time = "\(first.start.formatted(date: .omitted, time: .shortened)) – \(first.end.formatted(date: .omitted, time: .shortened))"
        return overlapping.count == 1
            ? "Overlaps with \(first.title) (\(time)). That's okay; both will show side by side."
            : "Overlaps with \(first.title) and \(overlapping.count - 1) more. That's okay; they'll show side by side."
    }

    private var navTitle: String {
        if !request.isNew { return "Edit Event" }
        if request.suggestionKey != nil { return "Add Suggestion" }
        return request.ideaID != nil ? "Schedule Idea" : "New Event"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .focused($titleFocused)
                        .submitLabel(.done)
                }

                Section {
                    Picker("Status", selection: $status) {
                        ForEach(PlanStatus.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Is this happening for sure?")
                } footer: {
                    Text(status == .potential
                         ? "A maybe: shows as a dashed block you can hide. Tap + on it once it's happening."
                         : "Happening for sure: shows as a solid block.")
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
                    if let overlapWarning {
                        Label(overlapWarning, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
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

                if canMoveBackToIdeas {
                    Section {
                        Button("Move Back to Ideas") {
                            store.moveBackToIdeas(request.event.id)
                            dismiss()
                        }
                    } footer: {
                        Text("Takes it off the calendar and keeps it in your Ideas for another time.")
                    }
                }

                if !request.isNew {
                    Section {
                        Button("Delete Event", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
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
            .onAppear {
                // Ideas the user does regularly stay in the list by default.
                if let ideaID = request.ideaID {
                    keepIdea = store.ideas.first { $0.id == ideaID }?.repeats ?? false
                }
            }
            .task {
                // Open the keyboard right away for a brand-new, untitled event.
                guard request.isNew, title.isEmpty else { return }
                try? await Task.sleep(for: .milliseconds(450))
                titleFocused = true
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
        if let key = request.suggestionKey {
            store.recordAccepted(key)
        }
        if let ideaID = request.ideaID, var idea = store.ideas.first(where: { $0.id == ideaID }) {
            if keepIdea {
                idea.repeats = true
                store.updateIdea(idea)
            } else {
                store.removeIdea(ideaID)
            }
        }
        onSaved(event.start)
        dismiss()
    }
}
