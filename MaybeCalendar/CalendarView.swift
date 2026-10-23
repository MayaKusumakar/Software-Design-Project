import SwiftUI

struct CalendarView: View {
    @Environment(Store.self) private var store
    @Binding var selectedDay: Date
    /// When set, the timeline scrolls to this time (e.g. right after saving an event).
    @Binding var focusDate: Date?
    @State private var editor: EditorRequest?
    @State private var ideaEditor: IdeaEditorRequest?
    @State private var openGap: SlotSuggestions?
    @State private var showingMonth = false
    @State private var undo: PlanUndo?
    @State private var confirmCount = 0
    @State private var addCount = 0
    @AppStorage("ideasTrayExpanded") private var trayExpanded = false

    var body: some View {
        NavigationStack {
            // Re-check once a minute so suggestions never start in the past.
            TimelineView(.everyMinute) { context in
                dayView(now: context.date)
            }
            .navigationTitle(selectedDay.formatted(.dateTime.month(.wide).year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Today") {
                        goTo(.now)
                        focusDate = .now
                    }
                }
                ToolbarItem(placement: .principal) {
                    Button { showingMonth = true } label: {
                        HStack(spacing: 4) {
                            Text(selectedDay.formatted(.dateTime.month(.wide).year()))
                                .font(.headline)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.primary)
                    }
                    .accessibilityLabel(selectedDay.formatted(.dateTime.month(.wide).year()))
                    .accessibilityHint("Shows the month and year")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            editor = .new(day: selectedDay, hour: EditorRequest.suggestedHour(for: selectedDay))
                        } label: {
                            Label("New Event", systemImage: "calendar.badge.plus")
                        }
                        Button { ideaEditor = .new } label: {
                            Label("New Idea", systemImage: "lightbulb")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add")
                }
            }
            .sheet(item: $editor) { request in
                EventEditorView(request: request) { savedDate in
                    goTo(savedDate)
                    focusDate = savedDate
                }
            }
            .sheet(item: $ideaEditor) { request in
                IdeaEditorView(request: request)
            }
            .sheet(item: $openGap) { plan in
                FreeTimeSheet(plan: plan, onAdd: add) { savedDate in
                    focusDate = savedDate
                }
            }
            .sheet(isPresented: $showingMonth) {
                MonthYearView(selectedDay: $selectedDay)
            }
            .sensoryFeedback(.success, trigger: confirmCount)
            .sensoryFeedback(.success, trigger: addCount)
        }
    }

    @ViewBuilder
    private func dayView(now: Date) -> some View {
        let dayEvents = store.events(on: selectedDay, includePotential: true)
        let visibleEvents = dayEvents.filter { store.showPotential || $0.status == .confirmed }
        let hiddenCount = dayEvents.count - visibleEvents.count
        let plans = store.suggestions(for: selectedDay, now: now)
        let shown = SuggestionEngine.shown(plans)

        VStack(spacing: 0) {
            WeekStrip(selectedDay: $selectedDay, now: now)

            HStack(spacing: 6) {
                DayStepButton(systemImage: "chevron.left", label: "Previous day") { step(-1) }
                Text(selectedDay.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .frame(minWidth: 92)
                DayStepButton(systemImage: "chevron.right", label: "Next day") { step(1) }
                Spacer(minLength: 4)
                PotentialLayerButton(isShowing: store.showPotential, hiddenCount: hiddenCount) {
                    withAnimation { store.showPotential.toggle() }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            Divider()

            DayTimeline(
                day: selectedDay,
                events: visibleEvents,
                focusDate: $focusDate,
                onTapTime: { minute in editor = .new(day: selectedDay, minute: minute) },
                onTapEvent: { editor = .edit($0) },
                onConfirm: { event in
                    withAnimation { store.confirm(event.id) }
                    confirmCount += 1
                },
                onMove: { event, start in
                    withAnimation(.snappy) { store.moveEvent(event.id, to: start) }
                },
                onResize: { event, end in
                    withAnimation(.snappy) { store.resizeEvent(event.id, end: end) }
                },
                suggestions: shown,
                onOpenSuggestion: { tapped in openGap = plans.first { $0.id == tapped.id } },
                onAddSuggestion: { tapped in add(tapped.suggestion) },
                onDropIdea: drop,
                onSwipeDay: step
            )
            .overlay(alignment: .top) {
                if visibleEvents.isEmpty, hiddenCount > 0 || shown.isEmpty {
                    Text(hiddenCount > 0
                         ? "Potential plans are hidden. Tap the eye button to show them."
                         : "No plans yet. Tap or hold an hour to add one.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 12)
                        .padding(.horizontal)
                        .allowsHitTesting(false)
                }
            }
            // Below the timeline rather than floating over it, so taps always reach these.
            VStack(spacing: 8) {
                if let undo {
                    UndoBar(undo: undo) {
                        withAnimation(.snappy) {
                            store.undo(undo)
                            self.undo = nil
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                IdeasTray(day: selectedDay, now: now, expanded: $trayExpanded,
                          onSchedule: schedule, onNewIdea: { ideaEditor = .new })
            }
            .padding(.horizontal)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .animation(.snappy, value: undo?.id)
            .animation(.snappy, value: trayExpanded)
        }
    }

    private func goTo(_ day: Date) {
        withAnimation(.snappy) { selectedDay = day }
    }

    private func step(_ days: Int) {
        goTo(Calendar.current.date(byAdding: .day, value: days, to: selectedDay)!)
    }

    /// One tap on a suggestion's + adds it as a potential plan, with a moment to undo.
    private func add(_ suggestion: Suggestion) {
        showUndo(withAnimation(.snappy) { store.add(suggestion) })
    }

    /// An idea dragged from the tray onto the timeline becomes a potential plan at that time.
    private func drop(_ id: Idea.ID, at start: Date) {
        guard let idea = store.ideas.first(where: { $0.id == id }) else { return }
        showUndo(withAnimation(.snappy) {
            store.addPlan(title: idea.title, start: start, minutes: idea.effectiveMinutes,
                          ideaID: idea.id, feedbackKey: SuggestionEngine.ideaKey(idea.id))
        })
    }

    /// Tapping an idea in the tray opens the editor at the first time it fits.
    private func schedule(_ idea: Idea, at fit: Date?) {
        let start = fit ?? Calendar.current.date(
            bySettingHour: EditorRequest.suggestedHour(for: selectedDay), minute: 0, second: 0, of: selectedDay)!
        editor = .new(start: start, minutes: idea.effectiveMinutes, title: idea.title, status: .potential, ideaID: idea.id)
    }

    private func showUndo(_ result: PlanUndo) {
        addCount += 1
        undo = result
        Task {
            try? await Task.sleep(for: .seconds(8))
            if undo?.id == result.id { withAnimation(.snappy) { undo = nil } }
        }
    }
}

private struct DayStepButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .accessibilityLabel(label)
    }
}

/// Shows or hides the potential-plans layer.
struct PotentialLayerButton: View {
    let isShowing: Bool
    let hiddenCount: Int
    let action: () -> Void

    private var icon: String { isShowing ? "eye" : "eye.slash" }

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                Label(isShowing ? "Potential shown"
                      : hiddenCount > 0 ? "\(hiddenCount) potential hidden" : "Potential hidden",
                      systemImage: icon)
                Label(isShowing ? "Shown" : hiddenCount > 0 ? "\(hiddenCount) hidden" : "Hidden", systemImage: icon)
                Image(systemName: icon)
            }
            .font(.subheadline)
            .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .tint(isShowing ? .accentColor : .gray)
        .accessibilityLabel("Show potential plans")
        .accessibilityValue(isShowing ? "On" : "Off")
    }
}

// MARK: - Week strip

struct WeekStrip: View {
    @Environment(Store.self) private var store
    @Binding var selectedDay: Date
    let now: Date

    private var days: [Date] {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: selectedDay)?.start ?? selectedDay
        return (0..<7).map { cal.date(byAdding: .day, value: $0, to: start)! }
    }

    var body: some View {
        HStack(spacing: 0) {
            weekButton(-1)

            ForEach(days, id: \.self) { day in
                dayCell(day)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.snappy) { selectedDay = day } }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
            }

            weekButton(1)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 8)
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                if value.translation.width < -50 { shiftWeek(1) }
                if value.translation.width > 50 { shiftWeek(-1) }
            }
        )
    }

    /// Big double arrows for weeks, so they're not confused with the single day arrows below.
    private func weekButton(_ weeks: Int) -> some View {
        Button { shiftWeek(weeks) } label: {
            Image(systemName: weeks < 0 ? "chevron.left.2" : "chevron.right.2")
                .font(.title3.weight(.semibold))
                .frame(width: 38, height: 48)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(weeks < 0 ? "Previous week" : "Next week")
    }

    private func dayCell(_ day: Date) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
        let isToday = cal.isDateInToday(day)
        let dayEvents = store.events(on: day, includePotential: store.showPotential)
        let hasConfirmed = dayEvents.contains { $0.status == .confirmed }
        let hasPotential = dayEvents.contains { $0.status == .potential }
        let hasIdea = day >= cal.startOfDay(for: now) && !store.suggestions(for: day, now: now).isEmpty

        return VStack(spacing: 4) {
            Text(day.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(day.formatted(.dateTime.day()))
                .font(.callout.weight(isSelected || isToday ? .bold : .regular))
                .foregroundStyle(isSelected ? Color.white : (isToday ? Color.accentColor : Color.primary))
                .frame(width: 32, height: 32)
                .background(Circle().fill(isSelected ? Color.accentColor : .clear))
            HStack(spacing: 3) {
                if hasConfirmed {
                    Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                }
                if hasPotential {
                    Circle().strokeBorder(Color.accentColor, lineWidth: 1).frame(width: 6, height: 6)
                }
                if hasIdea {
                    Circle().fill(Color.yellow).frame(width: 6, height: 6)
                }
            }
            .frame(height: 6)
        }
        .accessibilityValue(hasIdea ? "Has free time ideas" : "")
    }

    private func shiftWeek(_ weeks: Int) {
        withAnimation(.snappy) { selectedDay = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: selectedDay)! }
    }
}

// MARK: - Day timeline

struct DayTimeline: View {
    let day: Date
    let events: [PlanEvent]
    @Binding var focusDate: Date?
    /// Tapped or held an empty time, in minutes after midnight.
    let onTapTime: (Int) -> Void
    let onTapEvent: (PlanEvent) -> Void
    let onConfirm: (PlanEvent) -> Void
    var onMove: (PlanEvent, Date) -> Void = { _, _ in }
    var onResize: (PlanEvent, Date) -> Void = { _, _ in }
    var suggestions: [SuggestionEngine.Shown] = []
    var onOpenSuggestion: (SuggestionEngine.Shown) -> Void = { _ in }
    var onAddSuggestion: (SuggestionEngine.Shown) -> Void = { _ in }
    var onDropIdea: (Idea.ID, Date) -> Void = { _, _ in }
    /// +1 for the next day, -1 for the previous one.
    var onSwipeDay: (Int) -> Void = { _ in }

    @State private var didInitialScroll = false
    @State private var active: ActiveDrag?
    /// Set while a plan is being dragged, so letting go doesn't also count as a swipe to another day.
    @State private var suppressSwipe = false
    @State private var liftCount = 0

    private struct ActiveDrag: Equatable {
        var id: PlanEvent.ID
        var offset: CGFloat
        var resizing: Bool
    }

    private let hourHeight: CGFloat = 60
    private let labelWidth: CGFloat = 52
    private let snapMinutes = 15

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    hourGrid
                    suggestionsLayer
                    eventsLayer
                    if Calendar.current.isDateInToday(day) { nowLine }
                }
                .frame(height: hourHeight * 24)
                .dropDestination(for: String.self) { items, location in
                    guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                    onDropIdea(id, time(atY: location.y))
                    return true
                }
                // On the content, so the scroll view doesn't swallow sideways swipes.
                .simultaneousGesture(swipeGesture)
                .padding(.vertical, 8)
            }
            .scrollDisabled(active != nil)
            .sensoryFeedback(.impact(weight: .medium), trigger: liftCount)
            .onAppear {
                if let focusDate {
                    scroll(proxy, toHour: hour(of: focusDate))
                    self.focusDate = nil
                } else if !didInitialScroll {
                    scroll(proxy, toHour: defaultHour, animated: false)
                }
                didInitialScroll = true
            }
            .onChange(of: focusDate) { _, newValue in
                guard let newValue else { return }
                scroll(proxy, toHour: hour(of: newValue))
                focusDate = nil
            }
            .onChange(of: Calendar.current.startOfDay(for: day)) {
                // A save that changes the day also sets focusDate; let that win.
                guard focusDate == nil else { return }
                scroll(proxy, toHour: defaultHour)
            }
        }
    }

    /// Where to start when opening a day: just before now if it's today,
    /// otherwise just before the first event, otherwise 8am.
    private var defaultHour: Int {
        if Calendar.current.isDateInToday(day) { return hour(of: .now) }
        if let first = events.first { return hour(of: first.start) }
        return 8
    }

    private func hour(of date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    private func scroll(_ proxy: ScrollViewProxy, toHour hour: Int, animated: Bool = true) {
        // Show the hour before as context, and leave room so the hour label isn't clipped.
        let target = max(hour - 1, 0)
        if animated {
            withAnimation { proxy.scrollTo(target, anchor: UnitPoint(x: 0, y: 0.05)) }
        } else {
            proxy.scrollTo(target, anchor: UnitPoint(x: 0, y: 0.05))
        }
    }

    // MARK: Gestures

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if suppressSwipe {
                    suppressSwipe = false
                    return
                }
                let dx = value.translation.width, dy = value.translation.height
                if abs(dx) > 80, abs(dx) > abs(dy) * 2 { onSwipeDay(dx < 0 ? 1 : -1) }
            }
    }

    /// Press and hold a plan, then drag it up or down to move it.
    private func moveGesture(for event: PlanEvent) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if active?.id != event.id { liftCount += 1 }
                suppressSwipe = true
                active = ActiveDrag(id: event.id, offset: drag?.translation.height ?? 0, resizing: false)
            }
            .onEnded { value in
                defer { active = nil }
                guard case .second(true, let drag?) = value else { return }
                let start = movedStart(event, by: drag.translation.height)
                if start != event.start { onMove(event, start) }
            }
    }

    private func finishResize(_ event: PlanEvent, by offset: CGFloat) {
        defer { active = nil }
        let end = resizedEnd(event, by: offset)
        if end != event.end { onResize(event, end) }
    }

    private func snapped(_ offset: CGFloat) -> Int {
        Int((offset / hourHeight * 60 / CGFloat(snapMinutes)).rounded()) * snapMinutes
    }

    private var dayStart: Date { Calendar.current.startOfDay(for: day) }
    private var nextMidnight: Date { Calendar.current.date(byAdding: .day, value: 1, to: dayStart)! }

    private func movedStart(_ event: PlanEvent, by offset: CGFloat) -> Date {
        let length = event.end.timeIntervalSince(event.start)
        let start = event.start + TimeInterval(snapped(offset) * 60)
        return min(max(start, dayStart), nextMidnight - length)
    }

    private func resizedEnd(_ event: PlanEvent, by offset: CGFloat) -> Date {
        let end = event.end + TimeInterval(snapped(offset) * 60)
        return min(max(end, event.start + TimeInterval(snapMinutes * 60)), nextMidnight)
    }

    /// The time at a point on the timeline, snapped to 15 minutes.
    private func time(atY y: CGFloat) -> Date {
        let minute = Int((y / hourHeight * 60).rounded(.down))
        let snappedMinute = max(0, min(minute / snapMinutes * snapMinutes, 24 * 60 - snapMinutes))
        return Calendar.current.date(bySettingHour: snappedMinute / 60, minute: snappedMinute % 60, second: 0, of: day)!
    }

    // MARK: Layers

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 4) {
                    Text(hourLabel(hour))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: labelWidth - 4, alignment: .trailing)
                        .offset(y: -6)
                    VStack { Divider(); Spacer() }
                }
                .frame(height: hourHeight)
                .contentShape(Rectangle())
                // Tap the top or bottom half of an hour to start on the hour or half past;
                // pressing and holding works too.
                .onTapGesture { location in
                    onTapTime(hour * 60 + (location.y >= hourHeight / 2 ? 30 : 0))
                }
                .onLongPressGesture(minimumDuration: 0.35) { onTapTime(hour * 60) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Add event at \(hourLabel(hour).isEmpty ? "midnight" : hourLabel(hour))")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onTapTime(hour * 60) }
                .id(hour)
            }
        }
    }

    private var suggestionsLayer: some View {
        GeometryReader { geo in
            let columnWidth = geo.size.width - labelWidth - 8
            ForEach(suggestions) { shown in
                let suggestion = shown.suggestion
                let top = minutesIntoDay(suggestion.start) / 60 * hourHeight
                let bottom = minutesIntoDay(suggestion.end) / 60 * hourHeight
                let height = max(bottom - top - 2, 26)
                SuggestionGhost(suggestion: suggestion, height: height,
                                onOpen: { onOpenSuggestion(shown) },
                                onAdd: { onAddSuggestion(shown) })
                    .frame(width: columnWidth - 3, height: height)
                    .offset(x: labelWidth, y: top)
                    .transition(.opacity)
            }
        }
    }

    private var eventsLayer: some View {
        GeometryReader { geo in
            let columnWidth = geo.size.width - labelWidth - 8
            ForEach(layoutEvents(events)) { placed in
                let event = placed.event
                let drag = active?.id == event.id ? active : nil
                let start = drag.map { $0.resizing ? event.start : movedStart(event, by: $0.offset) } ?? event.start
                let end = drag.map { $0.resizing ? resizedEnd(event, by: $0.offset) : start + event.end.timeIntervalSince(event.start) } ?? event.end
                let top = minutesIntoDay(start) / 60 * hourHeight
                let bottom = min(minutesIntoDay(end), 24 * 60) / 60 * hourHeight
                let laneWidth = columnWidth / CGFloat(placed.lanes)
                EventBlock(
                    event: event,
                    shownStart: start,
                    shownEnd: end,
                    isLifted: drag != nil,
                    onConfirm: { onConfirm(event) },
                    onResizeChanged: { offset in
                        suppressSwipe = true
                        active = ActiveDrag(id: event.id, offset: offset, resizing: true)
                    },
                    onResizeEnded: { offset in finishResize(event, by: offset) }
                )
                .frame(width: laneWidth - 3, height: max(bottom - top - 2, 26))
                .offset(x: labelWidth + laneWidth * CGFloat(placed.lane), y: top)
                .zIndex(drag != nil ? 1 : 0)
                .onTapGesture { onTapEvent(event) }
                .gesture(moveGesture(for: event))
                .accessibilityAction(named: "Edit") { onTapEvent(event) }
                .accessibilityAction(named: "Move 30 minutes later") {
                    onMove(event, movedStart(event, by: hourHeight / 2))
                }
                .accessibilityAction(named: "Move 30 minutes earlier") {
                    onMove(event, movedStart(event, by: -hourHeight / 2))
                }
            }
        }
    }

    private var nowLine: some View {
        let y = minutesIntoDay(.now) / 60 * hourHeight
        return HStack(spacing: 0) {
            Circle().fill(.red).frame(width: 8, height: 8)
            Rectangle().fill(.red).frame(height: 1.5)
        }
        .padding(.leading, labelWidth - 4)
        .offset(y: y - 4)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func hourLabel(_ hour: Int) -> String {
        guard hour > 0 else { return "" }
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        return date.formatted(.dateTime.hour())
    }

    private func minutesIntoDay(_ date: Date) -> CGFloat {
        CGFloat(date.timeIntervalSince(dayStart) / 60)
    }
}

struct EventBlock: View {
    let event: PlanEvent
    /// The times to show, which differ from the saved ones while it's being dragged.
    var shownStart: Date?
    var shownEnd: Date?
    var isLifted = false
    let onConfirm: () -> Void
    var onResizeChanged: (CGFloat) -> Void = { _ in }
    var onResizeEnded: (CGFloat) -> Void = { _ in }

    private var isPotential: Bool { event.status == .potential }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.caption.bold())
                    .lineLimit(2)
                Text("\((shownStart ?? event.start).formatted(date: .omitted, time: .shortened)) – \((shownEnd ?? event.end).formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(isPotential ? Color.accentColor : .white)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .padding(.trailing, isPotential ? 24 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if isPotential {
                Button(action: onConfirm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .background(Circle().fill(.white))
                        .padding(3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Confirm \(event.title)")
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isPotential ? Color.accentColor.opacity(isLifted ? 0.2 : 0.12) : Color.accentColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: isPotential ? 1.5 : 0, dash: [5, 3]))
        )
        .overlay(alignment: .bottom) { resizeHandle }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(isLifted ? 0.25 : 0), radius: 8, y: 4)
        .scaleEffect(isLifted ? 1.02 : 1)
        .animation(.snappy(duration: 0.2), value: isLifted)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(event.title), \(event.status.label)")
        .accessibilityAddTraits(.isButton)
    }

    /// Drag the bottom edge to change when it ends.
    private var resizeHandle: some View {
        Capsule()
            .fill(isPotential ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.7))
            .frame(width: 24, height: 4)
            .frame(maxWidth: .infinity, minHeight: 14)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { onResizeChanged($0.translation.height) }
                    .onEnded { onResizeEnded($0.translation.height) }
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Overlap layout

struct PlacedEvent: Identifiable {
    let event: PlanEvent
    let lane: Int
    var lanes = 1
    var id: UUID { event.id }
}

/// Places overlapping events side by side. Each group of overlapping events shares the
/// same number of lanes so their widths line up.
func layoutEvents(_ list: [PlanEvent]) -> [PlacedEvent] {
    let sorted = list.sorted { ($0.start, $1.end) < ($1.start, $0.end) }
    var result: [PlacedEvent] = []
    var cluster: [PlacedEvent] = []
    var laneEnds: [Date] = []
    var clusterEnd = Date.distantPast

    func flush() {
        for var placed in cluster {
            placed.lanes = laneEnds.count
            result.append(placed)
        }
        cluster = []
        laneEnds = []
    }

    for event in sorted {
        let end = max(event.end, event.start.addingTimeInterval(20 * 60))
        if event.start >= clusterEnd { flush() }
        if let lane = laneEnds.firstIndex(where: { $0 <= event.start }) {
            laneEnds[lane] = end
            cluster.append(PlacedEvent(event: event, lane: lane))
        } else {
            cluster.append(PlacedEvent(event: event, lane: laneEnds.count))
            laneEnds.append(end)
        }
        clusterEnd = max(clusterEnd, end)
    }
    flush()
    return result
}
