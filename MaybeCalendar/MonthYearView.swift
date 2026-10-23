import SwiftUI

/// Jump to any day from a month grid, or pick a month from the whole year. Opens from the
/// month name at the top of the calendar.
struct MonthYearView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDay: Date

    @State private var mode: Mode = .month
    /// The first day of the month (or of a month in the year) being shown.
    @State private var shownMonth: Date

    enum Mode: String, CaseIterable, Identifiable {
        case month = "Month", year = "Year"
        var id: String { rawValue }
    }

    private let calendar = Calendar.current

    init(selectedDay: Binding<Date>) {
        _selectedDay = selectedDay
        let start = Calendar.current.dateInterval(of: .month, for: selectedDay.wrappedValue)?.start
        _shownMonth = State(initialValue: start ?? selectedDay.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack {
                    stepButton(-1)
                    Spacer()
                    Text(mode == .month
                         ? shownMonth.formatted(.dateTime.month(.wide).year())
                         : shownMonth.formatted(.dateTime.year()))
                        .font(.title3.bold())
                    Spacer()
                    stepButton(1)
                }

                Group {
                    if mode == .month {
                        monthGrid
                        legend
                    } else {
                        yearGrid
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 30).onEnded { value in
                        if value.translation.width < -50 { step(1) }
                        if value.translation.width > 50 { step(-1) }
                    }
                )

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Go to a Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Today") { pick(.now) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func stepButton(_ direction: Int) -> some View {
        Button { step(direction) } label: {
            Image(systemName: direction < 0 ? "chevron.left" : "chevron.right")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 36)
        }
        .accessibilityLabel(direction < 0
                            ? (mode == .month ? "Previous month" : "Previous year")
                            : (mode == .month ? "Next month" : "Next year"))
    }

    private func step(_ direction: Int) {
        withAnimation(.snappy) {
            shownMonth = calendar.date(byAdding: mode == .month ? .month : .year, value: direction, to: shownMonth)!
        }
    }

    private func pick(_ day: Date) {
        selectedDay = day
        dismiss()
    }

    // MARK: Month

    /// The month's days, with blanks before the 1st so it lines up under the right weekday.
    private func days(in month: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: month)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading)
            + range.map { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        let today = calendar.startOfDay(for: .now)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(days(in: shownMonth).enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day, today: today)
                } else {
                    Color.clear.frame(height: 48)
                }
            }
        }
    }

    private func dayCell(_ day: Date, today: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let dayEvents = store.events(on: day, includePotential: true)
        let hasConfirmed = dayEvents.contains { $0.status == .confirmed }
        let hasPotential = dayEvents.contains { $0.status == .potential }
        let hasIdea = day >= today && !store.suggestions(for: day).isEmpty

        return Button { pick(day) } label: {
            VStack(spacing: 3) {
                Text(day.formatted(.dateTime.day()))
                    .font(.callout.weight(isSelected || isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Color.accentColor : Color.primary))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(isSelected ? Color.accentColor : .clear))
                HStack(spacing: 2) {
                    if hasConfirmed { Circle().fill(Color.accentColor).frame(width: 5, height: 5) }
                    if hasPotential { Circle().strokeBorder(Color.accentColor, lineWidth: 1).frame(width: 5, height: 5) }
                    if hasIdea { Circle().fill(Color.yellow).frame(width: 5, height: 5) }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityValue([hasConfirmed ? "has plans" : nil, hasPotential ? "has maybes" : nil,
                             hasIdea ? "has free time ideas" : nil].compactMap { $0 }.joined(separator: ", "))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(Circle().fill(Color.accentColor), "Plans")
            legendItem(Circle().strokeBorder(Color.accentColor, lineWidth: 1), "Maybes")
            legendItem(Circle().fill(Color.yellow), "Free-time ideas")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private func legendItem(_ dot: some View, _ label: String) -> some View {
        HStack(spacing: 4) {
            dot.frame(width: 7, height: 7)
            Text(label)
        }
    }

    // MARK: Year

    private var yearGrid: some View {
        let year = calendar.component(.year, from: shownMonth)
        let months = (1...12).compactMap { calendar.date(from: DateComponents(year: year, month: $0, day: 1)) }
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
            ForEach(months, id: \.self) { month in
                Button {
                    withAnimation(.snappy) {
                        shownMonth = month
                        mode = .month
                    }
                } label: {
                    miniMonth(month)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(month.formatted(.dateTime.month(.wide).year()))
            }
        }
    }

    private func miniMonth(_ month: Date) -> some View {
        let isCurrent = calendar.isDate(month, equalTo: .now, toGranularity: .month)
        return VStack(alignment: .leading, spacing: 4) {
            Text(month.formatted(.dateTime.month(.abbreviated)))
                .font(.subheadline.bold())
                .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
            // Always six weeks, so every month in the grid is the same height.
            let days = days(in: month)
            let sixWeeks = days + Array(repeating: nil, count: max(0, 42 - days.count))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(Array(sixWeeks.enumerated()), id: \.offset) { _, day in
                    Text(day.map { $0.formatted(.dateTime.day()) } ?? "")
                        .font(.system(size: 8, weight: day.map { calendar.isDateInToday($0) } == true ? .bold : .regular))
                        .foregroundStyle(day.map { calendar.isDateInToday($0) } == true ? Color.accentColor : Color.secondary)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
    }
}
