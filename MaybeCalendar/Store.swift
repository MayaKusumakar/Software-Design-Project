import Foundation
import Observation

enum PlanStatus: String, Codable, CaseIterable, Identifiable {
    case confirmed, potential

    var id: String { rawValue }
    var label: String { self == .confirmed ? "Confirmed" : "Potential" }
}

struct PlanEvent: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var start: Date
    var end: Date
    var status: PlanStatus
    var notes: String = ""
    /// The idea this plan was scheduled from, if any.
    var ideaID: Idea.ID?
    /// Set once the user plans this as free time: from an idea or suggestion, or as a potential plan.
    var freeTime: Bool?

    /// Only free-time activities are learned from for suggestions, never classes or meetings.
    var isFreeTimeActivity: Bool { freeTime == true || ideaID != nil || status == .potential }
}

/// A free-time activity with no date yet.
struct Idea: Identifiable, Codable, Hashable {
    /// Assumed length when the user hasn't said how long an idea takes.
    static let defaultMinutes = 60

    var id = UUID()
    var title: String
    var notes: String = ""
    /// Roughly how long it takes, if the user said.
    var minutes: Int?
    var bestTime: BestTime?
    /// Something the user does again and again, so it stays in the list after scheduling.
    var repeats: Bool?
    var createdAt: Date?

    var effectiveMinutes: Int { max(minutes ?? Self.defaultMinutes, 5) }
}

/// Holds all app data and saves it to a JSON file in the app's Documents folder.
@MainActor
@Observable
final class Store {
    private(set) var events: [PlanEvent] = []
    private(set) var ideas: [Idea] = []
    private(set) var feedback: [String: SuggestionFeedback] = [:]
    var showPotential = true { didSet { save() } }

    private struct Snapshot: Codable {
        var events: [PlanEvent]
        var ideas: [Idea]
        var showPotential: Bool
        /// Missing in files saved before suggestions existed.
        var feedback: [String: SuggestionFeedback]?
    }

    private let fileURL: URL

    init(fileURL: URL = URL.documentsDirectory.appending(path: "maybe-calendar.json")) {
        self.fileURL = fileURL
        load()
    }

    // MARK: Events

    func events(on day: Date, includePotential: Bool) -> [PlanEvent] {
        events
            .filter { Calendar.current.isDate($0.start, inSameDayAs: day) }
            .filter { includePotential || $0.status == .confirmed }
            .sorted { $0.start < $1.start }
    }

    func upsert(_ event: PlanEvent) {
        var event = event
        if event.status == .potential || event.ideaID != nil { event.freeTime = true }
        if let i = events.firstIndex(where: { $0.id == event.id }) {
            events[i] = event
        } else {
            events.append(event)
        }
        save()
    }

    func confirm(_ id: PlanEvent.ID) {
        guard let i = events.firstIndex(where: { $0.id == id }) else { return }
        events[i].status = .confirmed
        save()
    }

    func deleteEvent(_ id: PlanEvent.ID) {
        events.removeAll { $0.id == id }
        save()
    }

    // MARK: Ideas

    func addIdea(_ title: String) {
        ideas.insert(Idea(title: title, createdAt: .now), at: 0)
        save()
    }

    func updateIdea(_ idea: Idea) {
        guard let i = ideas.firstIndex(where: { $0.id == idea.id }) else { return }
        ideas[i] = idea
        save()
    }

    func removeIdea(_ id: Idea.ID) {
        ideas.removeAll { $0.id == id }
        feedback[SuggestionEngine.ideaKey(id)] = nil
        save()
    }

    func removeIdeas(at offsets: IndexSet) {
        for idea in offsets.map({ ideas[$0] }) {
            feedback[SuggestionEngine.ideaKey(idea.id)] = nil
        }
        ideas.remove(atOffsets: offsets)
        save()
    }

    // MARK: Suggestions

    func suggestions(for day: Date, now: Date = .now) -> [SlotSuggestions] {
        SuggestionEngine.suggestions(for: day, events: events, ideas: ideas, feedback: feedback, now: now)
    }

    /// Called only once the user actually saves the suggested plan.
    func recordAccepted(_ key: String) {
        var entry = feedback[key, default: SuggestionFeedback()]
        entry.accepted += 1
        entry.lastAccepted = .now
        entry.dismissed = 0
        feedback[key] = entry
        save()
    }

    func recordDismissed(_ key: String) {
        var entry = feedback[key, default: SuggestionFeedback()]
        entry.dismissed += 1
        entry.lastDismissed = .now
        feedback[key] = entry
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        events = snapshot.events
        ideas = snapshot.ideas
        feedback = snapshot.feedback ?? [:]
        showPotential = snapshot.showPotential
    }

    private func save() {
        let snapshot = Snapshot(events: events, ideas: ideas, showPotential: showPotential, feedback: feedback)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Replaces all data with sample plans. Used when launched with `-demoData`.
    func loadDemoData() {
        let cal = Calendar.current
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let day = cal.date(byAdding: .day, value: dayOffset, to: .now)!
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        }
        events = [
            PlanEvent(title: "ECS 191 Lecture", start: at(0, 10), end: at(0, 11, 30), status: .confirmed),
            PlanEvent(title: "Coffee with Sam", start: at(0, 11), end: at(0, 12), status: .potential, notes: "If they're free after class"),
            PlanEvent(title: "Gym", start: at(0, 17), end: at(0, 18), status: .confirmed),
            PlanEvent(title: "Movie night", start: at(0, 19), end: at(0, 21), status: .potential),
            PlanEvent(title: "Study group", start: at(1, 14), end: at(1, 16), status: .confirmed),
            PlanEvent(title: "Farmers market", start: at(2, 9), end: at(2, 11), status: .potential),
        ]
        // A few past evening walks, so suggestions have some history to learn from.
        for daysAgo in [2, 4, 7, 9] {
            events.append(PlanEvent(title: "Evening walk", start: at(-daysAgo, 19), end: at(-daysAgo, 19, 30),
                                    status: .confirmed, freeTime: true))
        }
        let daysAgo = { (days: Int) in cal.date(byAdding: .day, value: -days, to: .now)! }
        ideas = [
            Idea(title: "Try the new ramen place", minutes: 60, createdAt: daysAgo(1)),
            Idea(title: "Practice guitar", minutes: 30, repeats: true, createdAt: daysAgo(10)),
            Idea(title: "Hike Stevens Trail", minutes: 180, bestTime: .morning, createdAt: daysAgo(20)),
            Idea(title: "Visit the arboretum", minutes: 90, createdAt: daysAgo(5)),
        ]
        feedback = [:]
        showPotential = true
        save()
    }
}
