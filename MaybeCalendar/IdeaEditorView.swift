import SwiftUI

/// What the idea editor sheet should open with.
struct IdeaEditorRequest: Identifiable {
    let id = UUID()
    var idea: Idea
    var isNew: Bool

    static var new: IdeaEditorRequest { IdeaEditorRequest(idea: Idea(title: ""), isNew: true) }
    static func edit(_ idea: Idea) -> IdeaEditorRequest { IdeaEditorRequest(idea: idea, isNew: false) }
}

/// Add, view or edit one idea. Everything except the title is optional.
struct IdeaEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let idea: Idea
    let isNew: Bool

    @State private var title: String
    @State private var notes: String
    @State private var minutes: Int?
    @State private var timing: Timing
    @State private var customFrom: Date
    @State private var customTo: Date
    @State private var category: String
    @State private var repeats: Bool
    @FocusState private var titleFocused: Bool

    private static let lengths = [15, 30, 45, 60, 90, 120, 180, 240]

    enum Timing: Hashable {
        case preset(BestTime)
        case custom
    }

    init(request: IdeaEditorRequest) {
        let idea = request.idea
        self.idea = idea
        self.isNew = request.isNew
        _title = State(initialValue: idea.title)
        _notes = State(initialValue: idea.notes)
        _minutes = State(initialValue: idea.minutes)
        _category = State(initialValue: idea.category ?? "")
        _repeats = State(initialValue: idea.repeats ?? false)

        let window = idea.timeWindow
        if let window, let preset = BestTime.allCases.first(where: { $0.window == window }) {
            _timing = State(initialValue: .preset(preset))
        } else if window != nil {
            _timing = State(initialValue: .custom)
        } else {
            _timing = State(initialValue: .preset(.any))
        }
        _customFrom = State(initialValue: Self.date(minute: window?.lowerBound ?? 18 * 60))
        _customTo = State(initialValue: Self.date(minute: window?.upperBound ?? 20 * 60))
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespaces) }

    private var window: Range<Int>? {
        switch timing {
        case .preset(let preset): preset.window
        case .custom:
            Self.minute(of: customTo) > Self.minute(of: customFrom)
                ? Self.minute(of: customFrom)..<Self.minute(of: customTo) : nil
        }
    }

    /// A time window too short for the activity means it would never be suggested.
    private var windowWarning: String? {
        if case .custom = timing, window == nil { return "The end time needs to be after the start time." }
        guard let window else { return nil }
        let length = minutes ?? Idea.defaultMinutes
        return window.count < length
            ? "That's shorter than \(durationText(minutes: length)), so it won't be suggested." : nil
    }

    /// A category recognized from the title, offered when none is chosen yet.
    private var recognizedCategory: String? {
        category.trimmingCharacters(in: .whitespaces).isEmpty ? IdeaCatalog.category(for: title) : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Something you want to do", text: $title)
                        .focused($titleFocused)
                        .submitLabel(.done)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section {
                    Picker("Takes about", selection: $minutes) {
                        Text("Not sure").tag(Int?.none)
                        ForEach(Self.lengths, id: \.self) { length in
                            Text(durationText(minutes: length)).tag(Int?.some(length))
                        }
                    }
                    Picker("When", selection: $timing) {
                        ForEach(BestTime.allCases) { preset in
                            Text(preset.window.map { "\(preset.label) (\(clockText(minute: $0.lowerBound))–\(clockText(minute: $0.upperBound)))" } ?? preset.label)
                                .tag(Timing.preset(preset))
                        }
                        Text("Custom times").tag(Timing.custom)
                    }
                    if case .custom = timing {
                        DatePicker("From", selection: $customFrom, displayedComponents: .hourAndMinute)
                        DatePicker("To", selection: $customTo, displayedComponents: .hourAndMinute)
                    }
                    if let windowWarning {
                        Label(windowWarning, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                } footer: {
                    Text("Suggestions only place this when you're free and inside these times. Not sure how long? We'll plan about \(durationText(minutes: Idea.defaultMinutes)).")
                }

                Section {
                    TextField("Category", text: $category)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if let recognizedCategory {
                                categoryChip(recognizedCategory, prefix: "Suggested: ")
                            }
                            ForEach(store.knownCategories.filter { $0 != recognizedCategory }, id: \.self) { name in
                                categoryChip(name)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Category")
                } footer: {
                    Text("Helps the app suggest new things you might like.")
                }

                Section {
                    Toggle("I do this regularly", isOn: $repeats)
                } footer: {
                    Text("Regular ideas stay in your list after you schedule them.")
                }

                if !isNew {
                    Section {
                        Button("Delete Idea", role: .destructive) {
                            store.removeIdea(idea.id)
                            dismiss()
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isNew ? "New Idea" : "Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save", action: save).disabled(trimmedTitle.isEmpty)
                }
            }
            .task {
                guard isNew else { return }
                try? await Task.sleep(for: .milliseconds(450))
                titleFocused = true
            }
        }
    }

    private func categoryChip(_ name: String, prefix: String = "") -> some View {
        let selected = category.caseInsensitiveCompare(name) == .orderedSame
        return Button("\(prefix)\(name)") { category = name }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .tint(selected ? .accentColor : .gray)
    }

    private func save() {
        var updated = idea
        updated.title = trimmedTitle
        updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.minutes = minutes
        updated.bestTime = nil
        updated.windowStart = window?.lowerBound
        updated.windowEnd = window?.upperBound
        let trimmedCategory = category.trimmingCharacters(in: .whitespaces)
        updated.category = trimmedCategory.isEmpty ? nil : trimmedCategory
        updated.repeats = repeats
        if isNew {
            updated.createdAt = .now
            store.addIdea(updated)
        } else {
            store.updateIdea(updated)
        }
        dismiss()
    }

    private static func date(minute: Int) -> Date {
        Calendar.current.date(bySettingHour: (minute / 60) % 24, minute: minute % 60, second: 0, of: .now) ?? .now
    }

    private static func minute(of date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
