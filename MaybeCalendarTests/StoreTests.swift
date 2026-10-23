import Foundation
import Testing
@testable import MaybeCalendar

@Suite("Saving")
@MainActor
struct StoreTests {
    let fileURL = FileManager.default.temporaryDirectory.appending(path: "store-test-\(UUID().uuidString).json")

    @Test func dataSavedBeforeSuggestionsStillLoads() throws {
        let oldFormat = """
        {"ideas":[{"id":"6F1A1E2B-1111-4E7B-9C3A-000000000001","title":"Hike Stevens Trail","notes":""}],
         "showPotential":false,
         "events":[{"id":"E784C8F5-0E27-4433-9507-97CD64974C23","title":"Try the new ramen place",
                    "start":813726000,"end":813729600,"status":"potential","notes":""}]}
        """
        try Data(oldFormat.utf8).write(to: fileURL)
        let store = Store(fileURL: fileURL)
        #expect(store.ideas.map(\.title) == ["Hike Stevens Trail"])
        #expect(store.ideas.first?.effectiveMinutes == Idea.defaultMinutes)
        #expect(store.events.map(\.title) == ["Try the new ramen place"])
        #expect(store.showPotential == false)
        #expect(store.feedback.isEmpty)
    }

    @Test func feedbackSurvivesARestart() {
        let store = Store(fileURL: fileURL)
        store.addIdea("Read")
        let key = SuggestionEngine.ideaKey(store.ideas[0].id)
        store.recordDismissed(key)
        store.recordDismissed(key)

        let reopened = Store(fileURL: fileURL)
        #expect(reopened.feedback[key]?.dismissed == 2)
        #expect(reopened.feedback[key]?.lastDismissed != nil)
    }

    @Test func acceptingASuggestionCreatesAPlanAndRemembersTheChoice() throws {
        let store = Store(fileURL: fileURL)
        store.addIdea("Practice guitar")
        var guitar = store.ideas[0]
        guitar.minutes = 30
        store.updateIdea(guitar)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        let suggestion = try #require(store.suggestions(for: tomorrow).first?.options.first)
        #expect(suggestion.minutes == 30)

        // What the editor does when the user taps Save.
        let request = EditorRequest.suggested(suggestion)
        store.upsert(request.event)
        store.recordAccepted(try #require(request.suggestionKey))

        let saved = try #require(store.events.first)
        #expect(saved.title == "Practice guitar")
        #expect(saved.status == .potential)
        #expect(saved.ideaID == guitar.id)
        #expect(saved.isFreeTimeActivity)
        #expect(saved.end.timeIntervalSince(saved.start) == 30 * 60)
        #expect(store.feedback[SuggestionEngine.ideaKey(guitar.id)]?.accepted == 1)
        // The new plan fills that time, so the same idea isn't offered again that day.
        #expect(!store.suggestions(for: tomorrow).flatMap(\.options).contains { $0.ideaID == guitar.id })
    }

    @Test func oldTimePresetsBecomeTimeBlocks() throws {
        let saved = """
        {"ideas":[{"id":"6F1A1E2B-1111-4E7B-9C3A-000000000002","title":"Walk","notes":"","bestTime":"evening"}],
         "showPotential":true,"events":[]}
        """
        try Data(saved.utf8).write(to: fileURL)
        let store = Store(fileURL: fileURL)
        #expect(store.ideas.first?.timeWindow == 17 * 60..<22 * 60)
        #expect(store.ideas.first?.timingText == "Evening")
    }

    @Test func addingInOneTapCanBeUndone() {
        let store = Store(fileURL: fileURL)
        store.addIdea("Read")
        let read = store.ideas[0]
        let start = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        let undo = store.addPlan(title: read.title, start: start, minutes: 45, ideaID: read.id,
                                 feedbackKey: SuggestionEngine.ideaKey(read.id))
        #expect(store.events.count == 1)
        #expect(store.events[0].status == .potential)
        #expect(store.ideas.isEmpty)  // it's scheduled now, so it leaves the list

        store.undo(undo)
        #expect(store.events.isEmpty)
        #expect(store.ideas.map(\.id) == [read.id])
        #expect(store.feedback[SuggestionEngine.ideaKey(read.id)] == nil)
    }

    @Test func regularIdeasStayWhenAdded() {
        let store = Store(fileURL: fileURL)
        store.addIdea(Idea(title: "Gym", repeats: true))
        store.addPlan(title: "Gym", start: .now, minutes: 60, ideaID: store.ideas[0].id)
        #expect(store.ideas.count == 1)
    }

    @Test func aPlanCanMoveBackToIdeas() throws {
        let store = Store(fileURL: fileURL)
        store.upsert(PlanEvent(title: "Pottery class", start: .now, end: .now + 90 * 60, status: .potential))
        let id = try #require(store.events.first).id
        store.moveBackToIdeas(id)
        #expect(store.events.isEmpty)
        #expect(store.ideas.first?.title == "Pottery class")
        #expect(store.ideas.first?.minutes == 90)
    }

    @Test func movingKeepsTheLengthAndResizingKeepsAMinimum() throws {
        let store = Store(fileURL: fileURL)
        let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
        store.upsert(PlanEvent(title: "Study", start: start, end: start + 3600, status: .confirmed))
        let id = try #require(store.events.first).id

        store.moveEvent(id, to: start + 2 * 3600)
        #expect(store.events[0].start == start + 2 * 3600)
        #expect(store.events[0].end == start + 3 * 3600)

        store.resizeEvent(id, end: start)  // before it starts
        #expect(store.events[0].end == store.events[0].start + 15 * 60)
    }

    @Test func deletingAnIdeaClearsItsFeedback() {
        let store = Store(fileURL: fileURL)
        store.addIdea("Read")
        let id = store.ideas[0].id
        store.recordDismissed(SuggestionEngine.ideaKey(id))
        store.removeIdea(id)
        #expect(store.feedback.isEmpty)
    }
}
