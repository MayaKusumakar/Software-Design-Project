import SwiftUI

/// The free-time suggestion shown at the bottom of the day view.
struct SuggestionCard: View {
    let shown: SuggestionEngine.Shown
    let onAdd: () -> Void
    let onAnother: () -> Void
    let onNotNow: () -> Void
    /// Opens the original idea, when the suggestion came from one.
    let onOpen: (() -> Void)?
    let onCollapse: () -> Void

    private var suggestion: Suggestion { shown.suggestion }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Free time idea")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onCollapse) {
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide suggestions")
            }
            .font(.caption.weight(.semibold))

            if let onOpen {
                Button(action: onOpen) { details(showsChevron: true) }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows the saved idea")
            } else {
                details(showsChevron: false)
            }

            HStack(spacing: 8) {
                Button("Add to Calendar", action: onAdd)
                    .buttonStyle(.borderedProminent)
                if shown.alternatives > 1 {
                    Button("Another idea", action: onAnother)
                        .buttonStyle(.bordered)
                }
                Spacer(minLength: 0)
                Button("Not now", action: onNotNow)
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .accessibilityHint("Hides this idea for a while")
            }
            .controlSize(.small)
            .buttonBorderShape(.capsule)
        }
        .suggestionCardStyle()
    }

    private func details(showsChevron: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(suggestion.title)
                    .font(.headline)
                    .lineLimit(2)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
            }
            Text("\(timeRange(suggestion.start, suggestion.end)) · \(durationText(minutes: suggestion.minutes))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(suggestion.reason)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// What the card shrinks to after "Hide suggestions".
struct SuggestionPill: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: action) {
                Label {
                    Text(count == 1 ? "Free time idea" : "\(count) free time ideas")
                } icon: {
                    Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06)))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show free time ideas")
        }
    }
}

/// Shown instead of suggestions when there's nothing to suggest from yet.
struct IdeasInviteCard: View {
    let onAddIdea: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                Text("Have something you've been wanting to do? Save it in Ideas and we'll help you find time for it.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Not now")
            }
            Button("Add an idea", action: onAddIdea)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
        }
        .suggestionCardStyle()
    }
}

/// Marks a suggestion's time on the timeline, set apart from real plans by its yellow dotted outline.
struct SuggestionGhost: View {
    let suggestion: Suggestion
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
            Text(suggestion.title)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .font(.caption)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.yellow.opacity(isSelected ? 0.18 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.yellow.opacity(isSelected ? 0.9 : 0.5), style: StrokeStyle(lineWidth: 1.2, dash: [2, 3]))
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Suggested: \(suggestion.title), \(timeRange(suggestion.start, suggestion.end))")
        .accessibilityAddTraits(.isButton)
    }
}

private struct SuggestionCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
            .shadow(color: .black.opacity(0.08), radius: 14, y: 4)
    }
}

extension View {
    fileprivate func suggestionCardStyle() -> some View { modifier(SuggestionCardStyle()) }
}

func timeRange(_ start: Date, _ end: Date) -> String {
    "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
}
