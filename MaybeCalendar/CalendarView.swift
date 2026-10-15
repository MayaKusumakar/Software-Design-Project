import SwiftUI

struct CalendarView: View {
    @Environment(Store.self) private var store
    @Binding var selectedDay: Date
    @State private var editor: EditorRequest?

    var body: some View {
        @Bindable var store = store
        let hiddenCount = store.showPotential ? 0
            : store.events(on: selectedDay, includePotential: true).filter { $0.status == .potential }.count

        NavigationStack {
            VStack(spacing: 0) {
                WeekStrip(selectedDay: $selectedDay)

                HStack {
                    Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.subheadline.bold())
                    Spacer()
                    Toggle(isOn: $store.showPotential) {
                        Text(hiddenCount > 0 ? "Potential (\(hiddenCount) hidden)" : "Potential")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize()
                    .accessibilityLabel("Show potential plans")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                DayTimeline(
                    day: selectedDay,
                    events: store.events(on: selectedDay, includePotential: store.showPotential),
                    onTapHour: { hour in editor = .new(day: selectedDay, hour: hour) },
                    onTapEvent: { editor = .edit($0) },
                    onConfirm: { event in
                        withAnimation { store.confirm(event.id) }
                    }
                )
            }
            .navigationTitle(selectedDay.formatted(.dateTime.month(.wide).year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Today") { selectedDay = .now }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editor = .new(day: selectedDay, hour: EditorRequest.suggestedHour(for: selectedDay))
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New event")
                }
            }
            .sheet(item: $editor) { request in
                EventEditorView(request: request) { savedDate in selectedDay = savedDate }
            }
        }
    }
}

// MARK: - Week strip

struct WeekStrip: View {
    @Environment(Store.self) private var store
    @Binding var selectedDay: Date

    private var days: [Date] {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: selectedDay)?.start ?? selectedDay
        return (0..<7).map { cal.date(byAdding: .day, value: $0, to: start)! }
    }

    var body: some View {
        HStack(spacing: 0) {
            Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left") }
                .padding(.horizontal, 8)
                .accessibilityLabel("Previous week")

            ForEach(days, id: \.self) { day in
                dayCell(day)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedDay = day }
            }

            Button { shiftWeek(1) } label: { Image(systemName: "chevron.right") }
                .padding(.horizontal, 8)
                .accessibilityLabel("Next week")
        }
        .padding(.vertical, 8)
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                if value.translation.width < -50 { shiftWeek(1) }
                if value.translation.width > 50 { shiftWeek(-1) }
            }
        )
    }

    private func dayCell(_ day: Date) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
        let isToday = cal.isDateInToday(day)
        let dayEvents = store.events(on: day, includePotential: store.showPotential)
        let hasConfirmed = dayEvents.contains { $0.status == .confirmed }
        let hasPotential = dayEvents.contains { $0.status == .potential }

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
                Circle().fill(Color.accentColor).frame(width: 5, height: 5).opacity(hasConfirmed ? 1 : 0)
                Circle().strokeBorder(Color.accentColor, lineWidth: 1).frame(width: 6, height: 6).opacity(hasPotential ? 1 : 0)
            }
        }
    }

    private func shiftWeek(_ weeks: Int) {
        withAnimation { selectedDay = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: selectedDay)! }
    }
}

// MARK: - Day timeline

struct DayTimeline: View {
    let day: Date
    let events: [PlanEvent]
    let onTapHour: (Int) -> Void
    let onTapEvent: (PlanEvent) -> Void
    let onConfirm: (PlanEvent) -> Void

    private let hourHeight: CGFloat = 60
    private let labelWidth: CGFloat = 52

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    hourGrid
                    eventsLayer
                    if Calendar.current.isDateInToday(day) { nowLine }
                }
                .frame(height: hourHeight * 24)
                .padding(.vertical, 8)
            }
            .onAppear { proxy.scrollTo(7, anchor: .top) }
        }
    }

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 4) {
                    Text(hourLabel(hour))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: labelWidth - 4, alignment: .trailing)
                        .offset(y: -6)
                    VStack { Divider() ; Spacer() }
                }
                .frame(height: hourHeight)
                .contentShape(Rectangle())
                .onTapGesture { onTapHour(hour) }
                .id(hour)
            }
        }
    }

    private var eventsLayer: some View {
        GeometryReader { geo in
            let columnWidth = geo.size.width - labelWidth - 8
            ForEach(layoutEvents(events)) { placed in
                let top = minutesIntoDay(placed.event.start) / 60 * hourHeight
                let bottom = min(minutesIntoDay(placed.event.end), 24 * 60) / 60 * hourHeight
                let laneWidth = columnWidth / CGFloat(placed.lanes)
                EventBlock(event: placed.event, onConfirm: { onConfirm(placed.event) })
                    .frame(width: laneWidth - 3, height: max(bottom - top - 2, 26))
                    .offset(x: labelWidth + laneWidth * CGFloat(placed.lane), y: top)
                    .onTapGesture { onTapEvent(placed.event) }
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
    }

    private func hourLabel(_ hour: Int) -> String {
        guard hour > 0 else { return "" }
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        return date.formatted(.dateTime.hour())
    }

    private func minutesIntoDay(_ date: Date) -> CGFloat {
        CGFloat(date.timeIntervalSince(Calendar.current.startOfDay(for: day)) / 60)
    }
}

struct EventBlock: View {
    let event: PlanEvent
    let onConfirm: () -> Void

    private var isPotential: Bool { event.status == .potential }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.caption.bold())
                    .lineLimit(2)
                Text("\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
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
                }
                .buttonStyle(.plain)
                .padding(3)
                .accessibilityLabel("Confirm \(event.title)")
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isPotential ? Color.accentColor.opacity(0.12) : Color.accentColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: isPotential ? 1.5 : 0, dash: [5, 3]))
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(event.title), \(event.status.label)")
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
