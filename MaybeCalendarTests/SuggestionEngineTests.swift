import Foundation
import Testing
@testable import MaybeCalendar

/// A fixed calendar, so results don't depend on the machine's time zone.
let pacific: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    cal.locale = Locale(identifier: "en_US")
    return cal
}()

/// A time in October 2026 (Oct 18 is a Sunday, Oct 19 a Monday).
func at(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10) -> Date {
    pacific.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

func plan(_ title: String, _ start: Date, _ end: Date, status: PlanStatus = .confirmed, freeTime: Bool? = nil) -> PlanEvent {
    PlanEvent(title: title, start: start, end: end, status: status, freeTime: freeTime)
}

func idea(_ title: String, minutes: Int? = nil, bestTime: BestTime? = nil) -> Idea {
    Idea(title: title, minutes: minutes, bestTime: bestTime)
}

/// Monday Oct 19, looked at early that morning.
let monday = at(19, 0)
let earlyMonday = at(19, 6)

/// Suggestions from the user's own ideas and habits; new ideas have their own tests.
func suggest(_ day: Date = monday, events: [PlanEvent] = [], ideas: [Idea] = [],
             feedback: [String: SuggestionFeedback] = [:], now: Date = earlyMonday,
             newIdeas: Bool = false) -> [SlotSuggestions] {
    var settings = SuggestionSettings()
    settings.includeNewIdeas = newIdeas
    return SuggestionEngine.suggestions(for: day, events: events, ideas: ideas, feedback: feedback, now: now,
                                        calendar: pacific, settings: settings)
}

/// Every plan except a free window from `start` to `end` on Monday, within the suggestion hours.
func onlyFree(_ start: Date, _ end: Date) -> [PlanEvent] {
    [plan("Busy", at(19, 8), start), plan("Busy", end, at(19, 22))]
}

@Suite("Free time")
struct FreeTimeTests {
    func slots(_ events: [PlanEvent], day: Date = monday, now: Date = earlyMonday) -> [FreeSlot] {
        SuggestionEngine.freeSlots(on: day, events: events, now: now, calendar: pacific)
    }

    @Test func findsTheGapsBetweenPlans() {
        let events = [
            plan("Class", at(19, 9), at(19, 10)),
            plan("Meeting", at(19, 11), at(19, 12)),
            plan("Work", at(19, 13), at(19, 15)),
        ]
        let found = slots(events)
        #expect(found.map(\.start) == [at(19, 8), at(19, 10), at(19, 12), at(19, 15)])
        #expect(found.map(\.end) == [at(19, 9), at(19, 11), at(19, 13), at(19, 22)])
        // Suggestions can use the whole hour, starting right on the hour.
        #expect(found[1].usableStart == at(19, 10))
        #expect(found[1].usableEnd == at(19, 11))
        #expect(found[2].minutes == 60)
    }

    @Test func overlappingAndBackToBackPlansLeaveNoGap() {
        let events = [
            plan("A", at(19, 9), at(19, 10, 30)),
            plan("B", at(19, 10), at(19, 11)),
            plan("C", at(19, 11), at(19, 12)),
        ]
        #expect(slots(events).map(\.start) == [at(19, 8), at(19, 12)])
    }

    @Test func gapsShorterThanTheMinimumAreSkipped() {
        let events = [plan("A", at(19, 9), at(19, 10)), plan("B", at(19, 10, 20), at(19, 11))]
        #expect(!slots(events).contains { $0.start == at(19, 10) })
    }

    @Test func potentialPlansCountAsBusy() {
        let events = [plan("Maybe coffee", at(19, 8), at(19, 21), status: .potential)]
        #expect(slots(events).map(\.start) == [at(19, 21)])
    }

    @Test func timeThatHasPassedIsSkipped() {
        let found = slots([], now: at(19, 12, 2))
        #expect(found.first?.start == at(19, 12, 15))
        #expect(slots([], day: at(18, 0), now: at(19, 12)).isEmpty)
    }

    @Test func planFromTheNightBeforeCountsAsBusy() {
        let events = [plan("Overnight", at(18, 20), at(19, 9))]
        #expect(slots(events).first?.start == at(19, 9))
        #expect(slots(events).first?.usableStart == at(19, 9))
    }

    @Test func freeTimeAfterAnOddEndStartsOnTheQuarterHour() {
        let events = [plan("Errand", at(19, 8), at(19, 8, 10))]
        #expect(slots(events).first?.usableStart == at(19, 8, 15))
    }

    @Test func planRunningPastMidnightStopsAtTheEndOfTheDay() {
        let events = [plan("Late show", at(19, 21), at(20, 2))]
        #expect(slots(events).last?.end == at(19, 21))
    }

    @Test func allDayPlanLeavesNoFreeTime() {
        #expect(slots([plan("Trip", at(19, 0), at(19, 23, 59))]).isEmpty)
    }

    @Test func brokenEventsAreIgnored() {
        #expect(slots([plan("Broken", at(19, 12), at(19, 11))]).count == 1)
    }

    @Test func daylightSavingDayHasTheRightLength() {
        // Clocks go back on Sunday, Nov 1, 2026.
        let found = slots([], day: at(1, 0, month: 11), now: at(31, 12))
        #expect(found.count == 1)
        #expect(found[0].end.timeIntervalSince(found[0].start) == 14 * 3600)
    }
}

@Suite("Suggestions")
struct SuggestionTests {
    @Test func aOneHourGapNeverGetsATwoHourIdea() {
        let ideas = [idea("Watch a movie", minutes: 120), idea("Read", minutes: 45)]
        let plans = suggest(events: onlyFree(at(19, 10), at(19, 11)), ideas: ideas)
        #expect(plans.flatMap(\.options).map(\.title) == ["Read"])
    }

    @Test func aShortBreakOnlyGetsWhatFits() {
        let ideas = [idea("Watch a movie", minutes: 120), idea("Go hiking", minutes: 180), idea("Practice guitar", minutes: 20)]
        let plans = suggest(events: onlyFree(at(19, 10), at(19, 10, 30)), ideas: ideas)
        #expect(plans.flatMap(\.options).map(\.title) == ["Practice guitar"])
        #expect(plans.first?.options.first?.reason == "From your Ideas · fits your 30-min break")
    }

    @Test func noIdeasAndNoFreeTimeHistoryMeansNoSuggestions() {
        // Confirmed plans with no free-time signal are never turned into suggestions.
        let gym = [12, 13, 14, 15].map { plan("Gym", at($0, 17), at($0, 18)) }
        #expect(suggest(events: gym).isEmpty)
    }

    @Test func aSavedIdeaIsSuggestedWithoutAnyHistory() {
        let plans = suggest(ideas: [idea("Visit the arboretum", minutes: 90)])
        let first = try! #require(plans.first?.options.first)
        #expect(first.title == "Visit the arboretum")
        #expect(first.start == at(19, 8))
        #expect(first.end == at(19, 9, 30))
        #expect(first.reason == "From your Ideas")
    }

    @Test func anIdeaWithoutALengthUsesTheDefault() {
        let fits = suggest(events: onlyFree(at(19, 10), at(19, 12)), ideas: [idea("Paint")])
        #expect(fits.first?.options.first?.minutes == Idea.defaultMinutes)
        // A 50-minute break isn't enough for the default hour.
        #expect(suggest(events: onlyFree(at(19, 10), at(19, 10, 50)), ideas: [idea("Paint")]).isEmpty)
    }

    @Test func aNewPlanRemovesSuggestionsItConflictsWith() {
        let ideas = [idea("Read", minutes: 45)]
        let before = suggest(events: onlyFree(at(19, 10), at(19, 12)), ideas: ideas)
        #expect(before.first?.options.first?.start == at(19, 10))

        let after = suggest(events: onlyFree(at(19, 10), at(19, 12)) + [plan("Meeting", at(19, 10), at(19, 12))], ideas: ideas)
        #expect(after.isEmpty)
    }

    @Test func noSuggestionEverOverlapsAPlan() {
        let events = [plan("A", at(19, 9), at(19, 10)), plan("B", at(19, 11), at(19, 12, 15)), plan("C", at(19, 14), at(19, 18))]
        let ideas = [idea("Walk", minutes: 30), idea("Read", minutes: 60), idea("Cook", minutes: 90)]
        for option in suggest(events: events, ideas: ideas).flatMap(\.options) {
            #expect(!events.contains { $0.start < option.end && $0.end > option.start })
        }
    }

    @Test func deletingAPlanOpensNewFreeTime() {
        let meeting = plan("Meeting", at(19, 10), at(19, 12))
        let events = onlyFree(at(19, 10), at(19, 12))
        #expect(suggest(events: events + [meeting], ideas: [idea("Read", minutes: 45)]).isEmpty)
        #expect(!suggest(events: events, ideas: [idea("Read", minutes: 45)]).isEmpty)
    }

    @Test func changingTheDayChangesTheSuggestions() {
        let events = [plan("Class", at(19, 8), at(19, 21)), plan("Class", at(20, 8), at(20, 9))]
        let ideas = [idea("Read", minutes: 45)]
        #expect(suggest(monday, events: events, ideas: ideas).first?.options.first?.start == at(19, 21))
        #expect(suggest(at(20, 0), events: events, ideas: ideas).first?.options.first?.start == at(20, 9))
    }

    @Test func notNowHidesAnIdeaUntilTheCooldownEnds() {
        let read = idea("Read", minutes: 45)
        let key = SuggestionEngine.ideaKey(read.id)
        let justDismissed = [key: SuggestionFeedback(dismissed: 1, lastDismissed: earlyMonday - 3600)]
        #expect(suggest(ideas: [read], feedback: justDismissed).isEmpty)

        let dismissedTwoDaysAgo = [key: SuggestionFeedback(dismissed: 1, lastDismissed: earlyMonday - 2 * 86_400)]
        #expect(!suggest(ideas: [read], feedback: dismissedTwoDaysAgo).isEmpty)
    }

    @Test func repeatedNotNowsWaitLonger() {
        let read = idea("Read", minutes: 45)
        let key = SuggestionEngine.ideaKey(read.id)
        let twice = [key: SuggestionFeedback(dismissed: 2, lastDismissed: earlyMonday - 2 * 86_400)]
        #expect(suggest(ideas: [read], feedback: twice).isEmpty)
        let manyTimes = [key: SuggestionFeedback(dismissed: 5, lastDismissed: earlyMonday - 5 * 86_400)]
        #expect(suggest(ideas: [read], feedback: manyTimes).isEmpty)
        let manyTimesLongAgo = [key: SuggestionFeedback(dismissed: 5, lastDismissed: earlyMonday - 8 * 86_400)]
        #expect(!suggest(ideas: [read], feedback: manyTimesLongAgo).isEmpty)
    }

    @Test func acceptedIdeasRankHigher() {
        let ideas = (1...5).map { idea("Idea \($0)", minutes: 45) }
        let picked = ideas[3]
        let feedback = [SuggestionEngine.ideaKey(picked.id): SuggestionFeedback(accepted: 2)]
        #expect(suggest(ideas: ideas, feedback: feedback).first?.options.first?.title == picked.title)
    }

    @Test func ideasWithTheSameScoreRotateFromDayToDay() {
        let ideas = (1...5).map { idea("Idea \($0)", minutes: 45) }
        let leaders = Set((19...25).compactMap { suggest(at($0, 0), ideas: ideas, now: at(18, 12)).first?.options.first?.title })
        #expect(leaders.count > 1)
    }

    @Test func resultsAreDeterministic() {
        let ideas = (1...5).map { idea("Idea \($0)", minutes: 30 * $0) }
        #expect(suggest(ideas: ideas) == suggest(ideas: ideas))
    }

    @Test func aBestTimeIsRespected() {
        let hike = idea("Hike", minutes: 120, bestTime: .morning)
        #expect(suggest(events: onlyFree(at(19, 13), at(19, 17)), ideas: [hike]).isEmpty)
        let morning = suggest(events: [plan("Lunch", at(19, 12), at(19, 13))], ideas: [hike], now: at(19, 7))
        #expect(morning.first?.options.first?.start == at(19, 8))
    }

    @Test func aCustomTimeBlockIsAHardLimit() {
        var guitar = idea("Practice guitar", minutes: 45)
        guitar.windowStart = 18 * 60
        guitar.windowEnd = 19 * 60
        #expect(suggest(ideas: [guitar]).first?.options.first?.start == at(19, 18))

        // 90 minutes can't fit inside a one-hour block, so it's never suggested.
        var movie = idea("Watch a movie", minutes: 90)
        movie.windowStart = 18 * 60
        movie.windowEnd = 19 * 60
        #expect(suggest(ideas: [movie]).isEmpty)
    }

    @Test func somethingAlreadyPlannedThatDayIsNotSuggestedAgain() {
        let read = idea("Read", minutes: 45)
        var planned = plan("Read", at(19, 20), at(19, 21), status: .potential)
        planned.ideaID = read.id
        #expect(suggest(events: [planned], ideas: [read]).isEmpty)
    }

    @Test func duplicateIdeasAreOfferedOnce() {
        let plans = suggest(ideas: [idea("Read a book", minutes: 30), idea("read a BOOK!", minutes: 30)])
        #expect(plans.first?.options.count == 1)
    }

    @Test func atMostTwoGapsGetSuggestions() {
        let events = [plan("A", at(19, 9), at(19, 10)), plan("B", at(19, 11), at(19, 12)),
                      plan("C", at(19, 13), at(19, 14)), plan("D", at(19, 15), at(19, 16))]
        #expect(suggest(events: events, ideas: [idea("Walk", minutes: 30)]).count == 2)
    }

    @Test func twoGapsShowDifferentIdeasAndAnotherIdeaCycles() {
        let events = [plan("A", at(19, 9), at(19, 10)), plan("B", at(19, 11), at(19, 22))]
        let ideas = [idea("Walk", minutes: 30), idea("Read", minutes: 30), idea("Stretch", minutes: 30)]
        let plans = suggest(events: events, ideas: ideas)
        #expect(plans.count == 2)

        let shown = SuggestionEngine.shown(plans, offsets: [:])
        #expect(Set(shown.map(\.suggestion.key)).count == shown.count)

        let gap = shown[0].id
        let cycle = (0..<shown[0].alternatives).map {
            SuggestionEngine.shown(plans, offsets: [gap: $0])[0].suggestion.title
        }
        #expect(Set(cycle).count == cycle.count)
        // After the last one it starts over.
        #expect(SuggestionEngine.shown(plans, offsets: [gap: cycle.count])[0].suggestion.title == cycle[0])
    }
}

@Suite("Learning from history")
struct HistoryTests {
    /// Four evening walks over the past two weeks, planned as free time.
    let walks = [5, 8, 12, 15].map {
        plan("Evening walk", at($0, 19), at($0, 19, 30), freeTime: true)
    }

    @Test func aRepeatedFreeTimeActivityBecomesASuggestion() {
        let plans = suggest(events: walks)
        let walk = try! #require(plans.flatMap(\.options).first { $0.title == "Evening walk" })
        #expect(walk.start == at(19, 19))
        #expect(walk.minutes == 30)
        #expect(walk.reason == "You often plan this in the evening")
    }

    @Test func aHabitIsOnlySuggestedAtItsUsualTimeOfDay() {
        let morningOnly = [plan("Busy", at(19, 12), at(19, 22))]
        #expect(suggest(events: walks + morningOnly).isEmpty)
    }

    @Test func historyIsNeverClaimedWithoutEnoughData() {
        #expect(suggest(events: Array(walks.prefix(2))).isEmpty)
    }

    @Test func classesAndMeetingsAreNeverSuggested() {
        let lectures = [5, 7, 12, 14].map { plan("ECS 191 Lecture", at($0, 10), at($0, 11)) }
        let meetings = [6, 8, 13, 15].map { plan("Team meeting", at($0, 16), at($0, 17), status: .potential) }
        #expect(SuggestionEngine.habits(from: lectures + meetings, now: earlyMonday, calendar: pacific).isEmpty)
        #expect(suggest(events: lectures + meetings).isEmpty)
    }

    @Test func weekdayPatternsAreDetected() {
        let reading = [4, 11, 18].map { plan("Reading", at($0, 15), at($0, 16), status: .potential) }
        let habit = try! #require(SuggestionEngine.habits(from: reading, now: earlyMonday, calendar: pacific).first)
        #expect(habit.weekday == 1)
        let sunday = suggest(at(25, 0), events: reading, now: earlyMonday)
        #expect(sunday.first?.options.first?.reason == "You often plan this on Sundays")
    }

    @Test func savedIdeasGenerallyRankAboveHabits() {
        let plans = suggest(events: walks, ideas: [idea("Read", minutes: 30)])
        #expect(plans.first?.options.first?.title == "Read")
    }

    @Test func anIdeaThatIsAlsoAHabitIsOfferedOnceWithItsPattern() {
        let plans = suggest(events: walks, ideas: [idea("Evening walk", minutes: 30)])
        let options = plans.flatMap(\.options).filter { $0.title == "Evening walk" }
        #expect(options.count == 1)
        #expect(options.first?.reason == "From your Ideas · usually in the evening")
        #expect(options.first?.ideaID != nil)
    }
}

@Suite("New ideas")
struct NewIdeaTests {
    @Test func categoriesAreRecognizedFromTitles() {
        #expect(IdeaCatalog.category(for: "Go hiking at Stevens Trail") == "Outdoors")
        #expect(IdeaCatalog.category(for: "Practice guitar") == "Music")
        #expect(IdeaCatalog.category(for: "Team meeting") == nil)
        #expect(idea("Sewing class").effectiveCategory == "Creative")
    }

    @Test func nothingIsSuggestedToSomeoneWithNoIdeasOrHistory() {
        #expect(suggest(newIdeas: true).isEmpty)
    }

    @Test func newIdeasComeFromWhatTheUserSaved() {
        let hike = idea("Hike Stevens Trail", minutes: 15 * 60)  // longer than any free day, so only new ideas show
        let options = suggest(ideas: [hike], newIdeas: true).flatMap(\.options)
        #expect(!options.isEmpty)
        for option in options {
            #expect(option.isNewIdea)
            #expect(option.reason == "New idea · because you saved Hike Stevens Trail")
            #expect(IdeaCatalog.item(forKey: SuggestionEngine.normalized(option.title))?.category == "Outdoors")
        }
    }

    @Test func newIdeasRankBelowTheUsersOwnAndNeverRepeatThem() {
        let ideas = [idea("Go on a bike ride", minutes: 60), idea("Read", minutes: 30)]
        let options = suggest(ideas: ideas, newIdeas: true).flatMap(\.options)
        #expect(options.filter { $0.title == "Go on a bike ride" }.allSatisfy { !$0.isNewIdea })
        for plan in suggest(ideas: ideas, newIdeas: true) {
            let firstNew = plan.options.firstIndex(where: \.isNewIdea) ?? plan.options.count
            #expect(plan.options[..<firstNew].allSatisfy { !$0.isNewIdea })
            #expect(plan.options[firstNew...].allSatisfy { $0.isNewIdea })
        }
    }

    @Test func aNewIdeaTheUserTriedCountsAsAnInterest() {
        let feedback = [SuggestionEngine.newIdeaKey("go for a run"): SuggestionFeedback(accepted: 1)]
        let interests = SuggestionEngine.interests(ideas: [], habits: [], feedback: feedback)
        #expect(interests == [SuggestionEngine.Interest(category: "Fitness", because: "because you tried Go for a run")])
    }
}

@Suite("Plan times")
struct PlanTimeTests {
    @Test func aPlanCanEndAtMidnight() {
        let day = at(19, 0)
        let end = PlanTime.end(day: day, start: at(19, 23), endTime: at(19, 0))
        #expect(end == at(20, 0))
    }

    @Test func otherEndTimesStayOnTheSameDay() {
        #expect(PlanTime.end(day: at(19, 0), start: at(19, 9), endTime: at(19, 10)) == at(19, 10))
        // A real mistake (ending before starting) is still caught.
        #expect(PlanTime.end(day: at(19, 0), start: at(19, 9), endTime: at(19, 8)) == at(19, 8))
    }
}
