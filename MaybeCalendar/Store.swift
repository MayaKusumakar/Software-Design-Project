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
}

/// A free-time activity with no date yet.
struct Idea: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var notes: String = ""
}

/// Holds all app data and saves it to a JSON file in the app's Documents folder.
@MainActor
@Observable
final class Store {
    private(set) var events: [PlanEvent] = []
    private(set) var ideas: [Idea] = []
    var showPotential = true { didSet { save() } }

    private struct Snapshot: Codable {
        var events: [PlanEvent]
        var ideas: [Idea]
        var showPotential: Bool
    }

    private let fileURL = URL.documentsDirectory.appending(path: "maybe-calendar.json")

    init() { load() }

    // MARK: Events

    func events(on day: Date, includePotential: Bool) -> [PlanEvent] {
        events
            .filter { Calendar.current.isDate($0.start, inSameDayAs: day) }
            .filter { includePotential || $0.status == .confirmed }
            .sorted { $0.start < $1.start }
    }

    func upsert(_ event: PlanEvent) {
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
        ideas.insert(Idea(title: title), at: 0)
        save()
    }

    func removeIdea(_ id: Idea.ID) {
        ideas.removeAll { $0.id == id }
        save()
    }

    func removeIdeas(at offsets: IndexSet) {
        ideas.remove(atOffsets: offsets)
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        events = snapshot.events
        ideas = snapshot.ideas
        showPotential = snapshot.showPotential
    }

    private func save() {
        let snapshot = Snapshot(events: events, ideas: ideas, showPotential: showPotential)
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
        ideas = [
            Idea(title: "Try the new ramen place"),
            Idea(title: "Hike Stevens Trail"),
            Idea(title: "Visit the arboretum"),
        ]
        showPotential = true
        save()
    }
}
