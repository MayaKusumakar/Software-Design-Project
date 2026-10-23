import SwiftUI

// MARK: - Suggestion on the timeline

/// A suggested activity drawn inside a free gap. Tap it to see every option for that time,
/// or tap + to add it straight away.
struct SuggestionGhost: View {
    let suggestion: Suggestion
    let height: CGFloat
    let onOpen: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(suggestion.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    if suggestion.isNewIdea {
                        Text("NEW")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.yellow.opacity(0.35)))
                    }
                }
                if height >= 40 {
                    Text("\(timeRange(suggestion.start, suggestion.end)) · \(durationText(minutes: suggestion.minutes))")
                        .font(.caption2)
                }
                if height >= 58 {
                    Text(suggestion.reason)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.primary.opacity(0.75))
            Spacer(minLength: 4)
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.orange)
                    .padding(2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(suggestion.title)")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.yellow.opacity(0.14)))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.yellow.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, dash: [2, 3]))
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Free time suggestion: \(suggestion.title), \(timeRange(suggestion.start, suggestion.end)). \(suggestion.reason)")
        .accessibilityHint("Shows other ideas for this time")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Add to calendar", onAdd)
    }
}

// MARK: - Every option for one free gap

/// Lists everything that fits one free gap: the user's own ideas and habits first, then a few
/// new ideas, each with why it was picked.
struct FreeTimeSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let plan: SlotSuggestions
    let onAdd: (Suggestion) -> Void
    /// Called after a plan is saved from the editor, with its start time.
    let onSaved: (Date) -> Void

    @State private var hidden: Set<String> = []
    @State private var editor: EditorRequest?

    private var options: [Suggestion] { plan.options.filter { !hidden.contains($0.key) } }
    private var yours: [Suggestion] { options.filter { !$0.isNewIdea } }
    private var newIdeas: [Suggestion] { Array(options.filter(\.isNewIdea).prefix(3)) }

    /// Saved ideas that don't fit this gap, so it's clear why they're missing.
    private var notFitting: Int {
        let fitting = Set(plan.options.compactMap(\.ideaID))
        return store.ideas.filter { !fitting.contains($0.id) }.count
    }

    var body: some View {
        NavigationStack {
            List {
                if !yours.isEmpty {
                    Section {
                        ForEach(yours) { row($0) }
                    } header: {
                        Text("From your ideas and habits")
                    } footer: {
                        if notFitting > 0 {
                            Text(notFitting == 1
                                 ? "1 of your ideas doesn't fit this time."
                                 : "\(notFitting) of your ideas don't fit this time.")
                        }
                    }
                }
                if !newIdeas.isEmpty {
                    Section("New ideas you might like") {
                        ForEach(newIdeas) { row($0) }
                    }
                }
                if options.isEmpty {
                    Text("Nothing else fits this time.")
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button {
                        editor = .new(start: plan.slot.usableStart, minutes: 60)
                    } label: {
                        Label("Plan something else here", systemImage: "calendar.badge.plus")
                    }
                } footer: {
                    Text("Tap an idea to change its time first. Swipe left on it for Not now.")
                }
            }
            .navigationTitle("Free \(timeRange(plan.slot.start, plan.slot.end))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editor) { request in
                EventEditorView(request: request) { savedDate in
                    onSaved(savedDate)
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ suggestion: Suggestion) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(.body.weight(.medium))
                Text("\(timeRange(suggestion.start, suggestion.end)) · \(durationText(minutes: suggestion.minutes))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(suggestion.reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("Add") {
                onAdd(suggestion)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
        .contentShape(Rectangle())
        .onTapGesture { editor = .suggested(suggestion) }
        .swipeActions(edge: .trailing) {
            Button("Not now") {
                store.recordDismissed(suggestion.key)
                withAnimation { _ = hidden.insert(suggestion.key) }
            }
            .tint(.gray)
            if suggestion.isNewIdea, let item = IdeaCatalog.item(forKey: SuggestionEngine.normalized(suggestion.title)) {
                Button("Save idea") {
                    store.addIdea(Idea(title: item.title, minutes: item.minutes, windowStart: item.window?.lowerBound,
                                       windowEnd: item.window?.upperBound, category: item.category, createdAt: .now))
                    withAnimation { _ = hidden.insert(suggestion.key) }
                }
                .tint(.yellow)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Add to calendar") {
            onAdd(suggestion)
            dismiss()
        }
    }
}

// MARK: - Ideas tray

/// The user's ideas at the bottom of the day view: drag one onto a time, or tap it to schedule.
/// Shrinks to a one-line bar so the calendar stays the focus.
struct IdeasTray: View {
    @Environment(Store.self) private var store
    let day: Date
    let now: Date
    @Binding var expanded: Bool
    let onSchedule: (Idea, Date?) -> Void
    let onNewIdea: () -> Void

    var body: some View {
        let fits = Dictionary(uniqueKeysWithValues: store.ideas.map {
            ($0.id, SuggestionEngine.firstFit(for: $0, on: day, events: store.events, now: now))
        })
        let fitCount = fits.values.compactMap { $0 }.count

        Group {
            if expanded {
                expandedTray(fits: fits)
            } else {
                Button { withAnimation(.snappy) { expanded = true } } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                        Text(summary(fitCount: fitCount))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .trayCardStyle()
                .accessibilityHint("Shows your ideas")
            }
        }
    }

    private func summary(fitCount: Int) -> String {
        if store.ideas.isEmpty { return "Save something to do in your free time" }
        let count = store.ideas.count == 1 ? "1 idea" : "\(store.ideas.count) ideas"
        if fitCount == 0 { return "\(count) · none fit this day" }
        return "\(count) · \(fitCount) fit this day"
    }

    private func expandedTray(fits: [Idea.ID: Date?]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Your ideas").font(.headline)
                    Text(store.ideas.isEmpty ? "Things you want to make time for" : "Drag one onto a time, or tap it")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onNewIdea) {
                    Image(systemName: "plus").font(.body.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("New idea")
                Button { withAnimation(.snappy) { expanded = false } } label: {
                    Image(systemName: "chevron.down").font(.body.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Hide ideas")
            }

            if store.ideas.isEmpty {
                Text("Have something you've been wanting to do? Save it and the app will find free time for it. Some to start with:")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(IdeaCatalog.starters) { item in
                            Button {
                                store.addIdea(Idea(title: item.title, minutes: item.minutes,
                                                   windowStart: item.window?.lowerBound, windowEnd: item.window?.upperBound,
                                                   category: item.category, createdAt: .now))
                            } label: {
                                Label(item.title, systemImage: "plus")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                        }
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.ideas) { idea in
                            let fit = fits[idea.id] ?? nil
                            IdeaChip(idea: idea, fit: fit)
                                .onTapGesture { onSchedule(idea, fit) }
                                .draggable(idea.id.uuidString) {
                                    Label(idea.title, systemImage: "lightbulb.fill")
                                        .padding(8)
                                        .background(.regularMaterial, in: Capsule())
                                }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(14)
        .trayCardStyle()
    }
}

struct IdeaChip: View {
    let idea: Idea
    /// Where it first fits on the shown day, if anywhere.
    let fit: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(idea.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text([durationText(minutes: idea.effectiveMinutes), idea.timingText].compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Label(fit.map { "Fits \($0.formatted(date: .omitted, time: .shortened))" } ?? "No room this day",
                  systemImage: fit == nil ? "clock.badge.xmark" : "clock")
                .font(.caption2.weight(.medium))
                .foregroundStyle(fit == nil ? Color.secondary : Color.orange)
        }
        .padding(10)
        .frame(width: 150, height: 92, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemBackground)))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double-tap to schedule. Drag onto the calendar to place it.")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Undo

struct UndoBar: View {
    let undo: PlanUndo
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text("Added \(undo.title) at \(undo.start.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button("Undo", action: onUndo)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .trayCardStyle()
    }
}

// MARK: - Shared

private struct TrayCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

extension View {
    fileprivate func trayCardStyle() -> some View { modifier(TrayCardStyle()) }
}

func timeRange(_ start: Date, _ end: Date) -> String {
    "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
}
