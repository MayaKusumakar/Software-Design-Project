import Foundation

/// Quick picks for when an idea fits best. The chosen window is stored on the idea in minutes.
enum BestTime: String, Codable, CaseIterable, Identifiable {
    case any, morning, afternoon, evening

    var id: String { rawValue }

    var label: String {
        switch self {
        case .any: "Any time"
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        }
    }

    /// "in the evening", used in suggestion explanations.
    var phrase: String { "in the \(label.lowercased())" }

    /// The hours used to recognize when past plans happened, as [start, end).
    var hours: Range<Int> {
        switch self {
        case .any: 0..<24
        case .morning: 5..<12
        case .afternoon: 12..<17
        case .evening: 17..<24
        }
    }

    /// The time window this quick pick gives an idea, in minutes since midnight.
    var window: Range<Int>? {
        switch self {
        case .any: nil
        case .morning: 8 * 60..<12 * 60
        case .afternoon: 12 * 60..<17 * 60
        case .evening: 17 * 60..<22 * 60
        }
    }

    static func partOfDay(hour: Int) -> BestTime? {
        [BestTime.morning, .afternoon, .evening].first { $0.hours.contains(hour) }
    }
}

/// What the user did with suggestions for one activity. Saved with the rest of the app data.
struct SuggestionFeedback: Codable, Hashable {
    var accepted = 0
    var lastAccepted: Date?
    /// "Not now" taps since the last time this was accepted.
    var dismissed = 0
    var lastDismissed: Date?
}

/// Tuning for free-time detection. All times are local.
struct SuggestionSettings {
    /// Only suggest during reasonable waking hours.
    var dayStartHour = 8
    var dayEndHour = 22
    /// Gaps shorter than this aren't worth suggesting anything for.
    var minimumFreeMinutes = 30
    /// Breathing room left before and after existing plans.
    var bufferMinutes = 0
    /// Suggestions start on the hour or a quarter past, never at odd times like :05.
    var roundingMinutes = 15
    /// At most this many gaps per day get a suggestion, so free time doesn't fill up with to-dos.
    var maxGaps = 2
    /// How long "Not now" hides an activity: 1 day, then 3, then 7 if dismissed again and again.
    var cooldownDays = [1, 3, 7]
    /// Also suggest new activities related to what the user has saved.
    var includeNewIdeas = true
}

/// An open stretch of time between plans.
struct FreeSlot: Hashable {
    /// The whole gap.
    var start: Date
    var end: Date
    /// The part an activity can use, after the buffer next to plans.
    var usableStart: Date
    var usableEnd: Date

    var minutes: Int { Int(end.timeIntervalSince(start) / 60) }
}

/// Something the user has planned for their free time again and again.
struct Habit: Hashable {
    /// The normalized title shared by all occurrences.
    var key: String
    var title: String
    var minutes: Int
    /// Distinct days it was planned on.
    var count: Int
    /// Set only when most occurrences share it.
    var partOfDay: BestTime?
    var usualStartMinute: Int?
    /// 1 = Sunday, as in `Calendar.component(.weekday:)`.
    var weekday: Int?
    var weekends = false
}

struct Suggestion: Identifiable, Hashable {
    enum Source: Hashable {
        case idea(Idea.ID)
        case habit(String)
        /// A new activity from `IdeaCatalog`, by its normalized title.
        case newIdea(String)
    }

    var source: Source
    var title: String
    var start: Date
    var end: Date
    /// A short, true explanation, e.g. "From your Ideas · fits your 60-min break".
    var reason: String
    var score: Double

    var minutes: Int { Int(end.timeIntervalSince(start) / 60) }

    var ideaID: Idea.ID? {
        if case .idea(let id) = source { return id }
        return nil
    }

    var isNewIdea: Bool {
        if case .newIdea = source { return true }
        return false
    }

    /// Identifies the activity for feedback, whatever time it's suggested for.
    var key: String {
        switch source {
        case .idea(let id): SuggestionEngine.ideaKey(id)
        case .habit(let key): SuggestionEngine.habitKey(key)
        case .newIdea(let key): SuggestionEngine.newIdeaKey(key)
        }
    }

    var id: String { "\(key)@\(start.timeIntervalSinceReferenceDate)" }
}

/// The ranked options for one free gap, best first.
struct SlotSuggestions: Identifiable, Hashable {
    var slot: FreeSlot
    var options: [Suggestion]

    /// The gap's end stays the same as the current time moves through it.
    var id: Date { slot.end }
}

/// Finds free time and ranks activities for it. Everything here is a pure function of its
/// inputs (including `now` and the calendar), so results are deterministic and testable.
enum SuggestionEngine {
    static func ideaKey(_ id: Idea.ID) -> String { "idea:\(id.uuidString)" }
    static func habitKey(_ titleKey: String) -> String { "habit:\(titleKey)" }
    static func newIdeaKey(_ titleKey: String) -> String { "new:\(titleKey)" }

    /// Lowercased words only, so "Evening Walk!" and "evening walk" match.
    static func normalized(_ title: String) -> String {
        title.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: " ")
    }

    // MARK: Free time

    static func freeSlots(on day: Date, events: [PlanEvent], now: Date,
                          calendar: Calendar = .current,
                          settings: SuggestionSettings = .init()) -> [FreeSlot] {
        guard let windowStart = calendar.date(bySettingHour: settings.dayStartHour, minute: 0, second: 0, of: day),
              let windowEnd = calendar.date(bySettingHour: settings.dayEndHour, minute: 0, second: 0, of: day)
        else { return [] }
        let start = max(windowStart, roundUp(now, toMinutes: settings.roundingMinutes))
        guard start < windowEnd else { return [] }

        // Every plan counts as busy, potential ones included, even ones that started the day before.
        let busy = events
            .filter { $0.end > $0.start && $0.end > start && $0.start < windowEnd }
            .map { (start: max($0.start, start), end: min($0.end, windowEnd)) }
            .sorted { $0.start < $1.start }

        let buffer = TimeInterval(settings.bufferMinutes * 60)
        var slots: [FreeSlot] = []
        func addGap(_ from: Date, _ to: Date, afterPlan: Bool, beforePlan: Bool) {
            guard to.timeIntervalSince(from) >= TimeInterval(settings.minimumFreeMinutes * 60) else { return }
            let usableStart = roundUp(afterPlan ? from + buffer : from, toMinutes: settings.roundingMinutes)
            let usableEnd = beforePlan ? to - buffer : to
            guard usableEnd > usableStart else { return }
            slots.append(FreeSlot(start: from, end: to, usableStart: usableStart, usableEnd: usableEnd))
        }

        var cursor = start
        var cursorIsPlanEnd = false
        for interval in busy {
            if interval.start > cursor {
                addGap(cursor, interval.start, afterPlan: cursorIsPlanEnd, beforePlan: true)
            }
            if interval.end >= cursor {
                cursor = interval.end
                cursorIsPlanEnd = true
            }
        }
        if cursor < windowEnd {
            addGap(cursor, windowEnd, afterPlan: cursorIsPlanEnd, beforePlan: false)
        }
        return slots
    }

    /// Rounds up to the next multiple of `step` minutes, so suggestions start at tidy times.
    static func roundUp(_ date: Date, toMinutes step: Int = 15) -> Date {
        let seconds = TimeInterval(max(step, 1) * 60)
        let t = date.timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (t / seconds).rounded(.up) * seconds)
    }

    /// `minute` minutes after midnight on `day`; 24:00 is the next midnight.
    static func date(atMinute minute: Int, on day: Date, calendar: Calendar) -> Date {
        let dayStart = calendar.startOfDay(for: day)
        if minute >= 24 * 60 { return calendar.date(byAdding: .day, value: 1, to: dayStart)! }
        return calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: dayStart)!
    }

    /// The earliest start in `slot` where an activity of `minutes` fits. A time window is a hard
    /// limit (the whole activity stays inside it); otherwise the user's usual start time is used
    /// when it fits.
    static func placement(minutes: Int, window: Range<Int>?, usualStartMinute: Int?,
                          in slot: FreeSlot, calendar: Calendar) -> Date? {
        let length = TimeInterval(minutes * 60)
        var start = slot.usableStart
        var latestEnd = slot.usableEnd
        if let window {
            start = max(start, date(atMinute: window.lowerBound, on: slot.start, calendar: calendar))
            latestEnd = min(latestEnd, date(atMinute: window.upperBound, on: slot.start, calendar: calendar))
        } else if let usual = usualStartMinute {
            let usualStart = date(atMinute: usual, on: slot.start, calendar: calendar)
            if usualStart >= slot.usableStart, usualStart + length <= slot.usableEnd {
                start = usualStart
            }
        }
        return start + length <= latestEnd ? start : nil
    }

    /// The first time on `day` an idea fits, for prefilling the editor and the ideas tray.
    static func firstFit(for idea: Idea, on day: Date, events: [PlanEvent], now: Date,
                         calendar: Calendar = .current) -> Date? {
        freeSlots(on: day, events: events, now: now, calendar: calendar).lazy
            .compactMap { placement(minutes: idea.effectiveMinutes, window: idea.timeWindow, usualStartMinute: nil, in: $0, calendar: calendar) }
            .first
    }

    // MARK: History

    /// Words that mark a plan as an obligation rather than something done for fun.
    static let obligationWords: Set<String> = [
        "class", "lecture", "lab", "discussion", "section", "seminar", "exam", "midterm", "final", "quiz",
        "homework", "deadline", "meeting", "standup", "sync", "interview", "work", "shift", "office",
        "appointment", "appt", "doctor", "dentist", "therapy", "commute",
    ]

    static func looksLikeObligation(_ title: String) -> Bool {
        normalized(title).split(separator: " ").contains { obligationWords.contains(String($0)) }
    }

    /// Free-time activities planned on at least `minimumDays` different days recently. To stay
    /// conservative, only plans with a clear free-time signal count (scheduled from an idea or a
    /// suggestion, or marked potential), and anything that sounds like an obligation is skipped.
    static func habits(from events: [PlanEvent], now: Date, calendar: Calendar = .current,
                       lookbackDays: Int = 60, minimumDays: Int = 3) -> [Habit] {
        guard let since = calendar.date(byAdding: .day, value: -lookbackDays, to: now) else { return [] }
        let past = events.filter {
            $0.end > $0.start && $0.end <= now && $0.start >= since
                && $0.isFreeTimeActivity && !looksLikeObligation($0.title)
        }

        return Dictionary(grouping: past) { normalized($0.title) }
            .compactMap { key, group -> Habit? in
                let days = Set(group.map { calendar.startOfDay(for: $0.start) })
                guard !key.isEmpty, days.count >= minimumDays else { return nil }
                let sorted = group.sorted { $0.start < $1.start }

                let part = dominant(group.compactMap { BestTime.partOfDay(hour: calendar.component(.hour, from: $0.start)) },
                                    of: group.count, share: 0.6)
                let usualStart = part.map { part in
                    median(group
                        .filter { BestTime.partOfDay(hour: calendar.component(.hour, from: $0.start)) == part }
                        .map { calendar.component(.hour, from: $0.start) * 60 + calendar.component(.minute, from: $0.start) })
                }
                let weekdays = group.map { calendar.component(.weekday, from: $0.start) }
                var weekday = dominant(weekdays, of: group.count, share: 0.6)
                if let day = weekday, weekdays.filter({ $0 == day }).count < 3 { weekday = nil }
                let weekendShare = Double(group.filter { calendar.isDateInWeekend($0.start) }.count) / Double(group.count)

                let minutes = median(group.map { Int($0.end.timeIntervalSince($0.start) / 60) })
                return Habit(
                    key: key,
                    title: sorted.last!.title,
                    minutes: min(max((minutes + 4) / 5 * 5, 15), 240),
                    count: days.count,
                    partOfDay: part,
                    usualStartMinute: usualStart.map { $0 / 5 * 5 },
                    weekday: weekday,
                    weekends: weekday == nil && weekendShare >= 0.75
                )
            }
            .sorted { $0.key < $1.key }
    }

    /// The most common value, if at least `share` of `total` items have it.
    private static func dominant<T: Hashable>(_ values: [T], of total: Int, share: Double) -> T? {
        let counts = Dictionary(values.map { ($0, 1) }, uniquingKeysWith: +)
        guard let best = counts.max(by: { ($0.value, "\($1.key)") < ($1.value, "\($0.key)") }),
              Double(best.value) >= share * Double(total) else { return nil }
        return best.key
    }

    private static func median(_ values: [Int]) -> Int {
        let sorted = values.sorted()
        return sorted.isEmpty ? 0 : sorted[sorted.count / 2]
    }

    // MARK: Interests

    /// A kind of activity the user has shown they like, and the evidence for it.
    struct Interest: Hashable {
        var category: String
        /// Ends the explanation, e.g. "because you saved Hike Stevens Trail".
        var because: String
    }

    /// Categories the user has shown interest in, taken only from their own ideas, habits and
    /// new ideas they've added before. Nothing is assumed about someone with no history.
    static func interests(ideas: [Idea], habits: [Habit], feedback: [String: SuggestionFeedback]) -> [Interest] {
        var result: [Interest] = []
        var seen = Set<String>()
        func note(_ category: String?, _ because: String) {
            guard let category, seen.insert(category.lowercased()).inserted else { return }
            result.append(Interest(category: category, because: because))
        }
        for idea in ideas { note(idea.effectiveCategory, "because you saved \(idea.title)") }
        for habit in habits { note(IdeaCatalog.category(for: habit.title), "because you often plan \(habit.title)") }
        for (key, entry) in feedback.sorted(by: { $0.key < $1.key }) where entry.accepted > 0 && key.hasPrefix("new:") {
            if let item = IdeaCatalog.item(forKey: String(key.dropFirst(4))) {
                note(item.category, "because you tried \(item.title)")
            }
        }
        return result
    }

    // MARK: Ranking

    /// Something that could fill free time: a saved idea, a habit that isn't already an idea, or
    /// a new idea related to what the user likes.
    struct Candidate {
        enum Kind { case idea(Idea.ID), habit, newIdea(because: String) }

        var kind: Kind
        var key: String
        var titleKey: String
        var title: String
        var minutes: Int
        var window: Range<Int>?
        var habit: Habit?
        var createdAt: Date?
        var everScheduled: Bool

        var ideaID: Idea.ID? {
            if case .idea(let id) = kind { return id }
            return nil
        }
    }

    static func candidates(ideas: [Idea], events: [PlanEvent], feedback: [String: SuggestionFeedback],
                           now: Date, calendar: Calendar, includeNewIdeas: Bool = true) -> [Candidate] {
        let habits = habits(from: events, now: now, calendar: calendar)
        let habitsByKey = Dictionary(uniqueKeysWithValues: habits.map { ($0.key, $0) })
        let scheduled = activityKeys(of: events)
        var seen = Set<String>()
        var result: [Candidate] = []

        for idea in ideas {
            let titleKey = normalized(idea.title)
            // Duplicate ideas are offered once.
            guard !titleKey.isEmpty, seen.insert(titleKey).inserted else { continue }
            result.append(Candidate(
                kind: .idea(idea.id), key: ideaKey(idea.id), titleKey: titleKey, title: idea.title,
                minutes: idea.effectiveMinutes, window: idea.timeWindow,
                habit: habitsByKey[titleKey], createdAt: idea.createdAt,
                everScheduled: scheduled.contains(ideaKey(idea.id)) || scheduled.contains(titleKey)
            ))
        }
        for habit in habits where seen.insert(habit.key).inserted {
            result.append(Candidate(
                kind: .habit, key: habitKey(habit.key), titleKey: habit.key, title: habit.title,
                minutes: habit.minutes, window: nil, habit: habit, createdAt: nil, everScheduled: true
            ))
        }
        guard includeNewIdeas else { return result }
        for interest in interests(ideas: ideas, habits: habits, feedback: feedback) {
            for item in IdeaCatalog.ideas(in: interest.category) {
                let titleKey = normalized(item.title)
                guard seen.insert(titleKey).inserted else { continue }
                result.append(Candidate(
                    kind: .newIdea(because: interest.because), key: newIdeaKey(titleKey), titleKey: titleKey,
                    title: item.title, minutes: item.minutes, window: item.window, habit: nil, createdAt: nil,
                    everScheduled: scheduled.contains(titleKey)
                ))
            }
        }
        return result
    }

    /// Normalized titles and linked idea keys of the given events.
    private static func activityKeys(of events: [PlanEvent]) -> Set<String> {
        Set(events.flatMap { event in [normalized(event.title)] + (event.ideaID.map { [ideaKey($0)] } ?? []) })
    }

    static func isCoolingDown(_ feedback: SuggestionFeedback?, now: Date,
                              settings: SuggestionSettings = .init()) -> Bool {
        guard let feedback, feedback.dismissed > 0, let last = feedback.lastDismissed,
              !settings.cooldownDays.isEmpty else { return false }
        let days = settings.cooldownDays[min(feedback.dismissed, settings.cooldownDays.count) - 1]
        return now < last + TimeInterval(days) * 86_400
    }

    /// Ranked suggestions for the next free gaps on `day`, in time order.
    static func suggestions(for day: Date, events: [PlanEvent], ideas: [Idea],
                            feedback: [String: SuggestionFeedback], now: Date,
                            calendar: Calendar = .current,
                            settings: SuggestionSettings = .init()) -> [SlotSuggestions] {
        let slots = freeSlots(on: day, events: events, now: now, calendar: calendar, settings: settings)
        guard !slots.isEmpty else { return [] }
        let candidates = candidates(ideas: ideas, events: events, feedback: feedback, now: now,
                                    calendar: calendar, includeNewIdeas: settings.includeNewIdeas)
        guard !candidates.isEmpty else { return [] }

        let dayStart = calendar.startOfDay(for: day)
        func eventsStarting(_ fromDays: Int, _ toDays: Int) -> [PlanEvent] {
            let from = calendar.date(byAdding: .day, value: fromDays, to: dayStart)!
            let to = calendar.date(byAdding: .day, value: toDays, to: dayStart)!
            return events.filter { $0.start >= from && $0.start < to }
        }
        let context = RankingContext(
            day: dayStart,
            dayLabel: calendar.dateComponents([.year, .month, .day], from: dayStart).description,
            sameDay: activityKeys(of: eventsStarting(0, 1)),
            nearby: activityKeys(of: eventsStarting(-2, 3)),
            feedback: feedback, now: now, calendar: calendar, settings: settings
        )

        // The soonest free time is the most useful to fill, so the first gaps that have
        // something fitting get suggestions, in time order.
        let plans = slots.lazy.compactMap { slot -> SlotSuggestions? in
            let options = candidates
                .compactMap { suggestion(for: $0, in: slot, context: context) }
                .sorted { $0.score != $1.score ? $0.score > $1.score : $0.key < $1.key }
            return options.isEmpty ? nil : SlotSuggestions(slot: slot, options: options)
        }
        return Array(plans.prefix(settings.maxGaps))
    }

    private struct RankingContext {
        var day: Date
        var dayLabel: String
        var sameDay: Set<String>
        var nearby: Set<String>
        var feedback: [String: SuggestionFeedback]
        var now: Date
        var calendar: Calendar
        var settings: SuggestionSettings
    }

    private static func suggestion(for c: Candidate, in slot: FreeSlot, context: RankingContext) -> Suggestion? {
        let calendar = context.calendar
        let feedback = context.feedback[c.key]
        if isCoolingDown(feedback, now: context.now, settings: context.settings) { return nil }
        // Already on the calendar that day.
        if context.sameDay.contains(c.titleKey) || c.ideaID.map({ context.sameDay.contains(ideaKey($0)) }) == true {
            return nil
        }
        guard let start = placement(minutes: c.minutes, window: c.window,
                                    usualStartMinute: c.habit?.usualStartMinute, in: slot, calendar: calendar)
        else { return nil }

        // Saved ideas come first; habits are inferred, and new ideas are only related to what's saved.
        var score: Double
        switch c.kind {
        case .idea: score = 100
        case .habit: score = 60
        case .newIdea: score = 45
        }
        // A time pattern from the user's own history, mentioned only when this time matches it.
        var pattern: String?

        if let feedback { score += Double(min(feedback.accepted, 3)) * 8 }
        if let habit = c.habit {
            score += c.ideaID != nil ? 10 : Double(min(habit.count, 5)) * 2
            if let part = habit.partOfDay {
                if BestTime.partOfDay(hour: calendar.component(.hour, from: start)) == part {
                    score += 20
                    pattern = part.phrase
                } else if c.ideaID == nil {
                    // Something learned only from history isn't offered at an unusual time
                    // (no evening walk at 8 AM).
                    return nil
                } else {
                    score -= 25
                }
            }
            if let weekday = habit.weekday {
                if weekday == calendar.component(.weekday, from: context.day) {
                    score += 15
                    pattern = "on \(calendar.weekdaySymbols[weekday - 1])s"
                } else {
                    score -= 10
                }
            } else if habit.weekends {
                if calendar.isDateInWeekend(context.day) {
                    score += 10
                    pattern = "on weekends"
                } else {
                    score -= 10
                }
            }
        }
        if c.window != nil { score += 10 }

        // Prefer activities that use a short break well.
        let usable = slot.usableEnd.timeIntervalSince(slot.usableStart)
        score += 10 * min(1, TimeInterval(c.minutes * 60) / usable)

        var ageNote: String?
        if let created = c.createdAt {
            let ageDays = context.now.timeIntervalSince(created) / 86_400
            if ageDays < 3 {
                score += 5
            } else if ageDays >= 14, !c.everScheduled {
                // Bring back ideas that have been waiting a while.
                score += 6
                ageNote = "saved \(Int(ageDays / 7)) weeks ago"
            }
        }
        if context.nearby.contains(c.titleKey) || c.ideaID.map({ context.nearby.contains(ideaKey($0)) }) == true {
            score -= 15
        }
        if let feedback, feedback.dismissed > 0, let last = feedback.lastDismissed,
           context.now.timeIntervalSince(last) < 14 * 86_400 {
            score -= Double(min(feedback.dismissed, 3)) * 6
        }
        // Rotate similar ideas from day to day without being random.
        score += 12 * stableUnit("\(c.key)|\(context.dayLabel)")

        let reason: String
        let source: Suggestion.Source
        switch c.kind {
        case .idea(let id):
            let detail = pattern.map { "usually \($0)" }
                ?? ageNote
                ?? (slot.minutes <= 90 ? "fits your \(slot.minutes)-min break" : nil)
            reason = ["From your Ideas", detail].compactMap { $0 }.joined(separator: " · ")
            source = .idea(id)
        case .habit:
            reason = pattern.map { "You often plan this \($0)" }
                ?? "You've planned this \(c.habit?.count ?? 0) times recently"
            source = .habit(c.titleKey)
        case .newIdea(let because):
            reason = "New idea · \(because)"
            source = .newIdea(c.titleKey)
        }

        return Suggestion(
            source: source,
            title: c.title,
            start: start,
            end: start + TimeInterval(c.minutes * 60),
            reason: reason,
            score: score
        )
    }

    /// A number in [0, 1) that depends only on `text` (Swift's `Hasher` changes every launch).
    static func stableUnit(_ text: String) -> Double {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        return Double(hash % 10_000) / 10_000
    }

    // MARK: Display

    struct Shown: Identifiable, Hashable {
        var suggestion: Suggestion
        var slot: FreeSlot
        /// How many different activities fit this gap.
        var alternatives: Int
        var id: Date { slot.end }
    }

    /// One suggestion per gap, never the same activity twice in a day. `offsets` steps through
    /// each gap's alternatives.
    static func shown(_ plans: [SlotSuggestions], offsets: [Date: Int] = [:]) -> [Shown] {
        var used = Set<String>()
        return plans.compactMap { plan in
            let options = plan.options.filter { !used.contains($0.key) }
            guard !options.isEmpty else { return nil }
            let pick = options[(offsets[plan.id] ?? 0) % options.count]
            used.insert(pick.key)
            return Shown(suggestion: pick, slot: plan.slot, alternatives: options.count)
        }
    }
}

/// "20 min", "1 hr", "1 hr 30 min".
func durationText(minutes: Int) -> String {
    let hours = minutes / 60, rest = minutes % 60
    if hours == 0 { return "\(rest) min" }
    return rest == 0 ? "\(hours) hr" : "\(hours) hr \(rest) min"
}

/// "6:30 PM" for a number of minutes after midnight.
func clockText(minute: Int) -> String {
    let date = Calendar.current.date(bySettingHour: (minute / 60) % 24, minute: minute % 60, second: 0, of: .now) ?? .now
    return date.formatted(date: .omitted, time: .shortened)
}
