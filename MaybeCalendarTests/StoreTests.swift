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

    @Test func deletingAnIdeaClearsItsFeedback() {
        let store = Store(fileURL: fileURL)
        store.addIdea("Read")
        let id = store.ideas[0].id
        store.recordDismissed(SuggestionEngine.ideaKey(id))
        store.removeIdea(id)
        #expect(store.feedback.isEmpty)
    }
}
