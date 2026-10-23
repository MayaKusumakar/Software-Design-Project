import Foundation

/// A ready-made activity the app can suggest once it knows the user likes its category.
struct CatalogIdea: Hashable, Identifiable {
    var title: String
    var minutes: Int
    var category: String
    /// When it makes sense, in minutes since midnight.
    var window: Range<Int>?

    var id: String { title }
}

/// Built-in activities and the words that place a user's own idea in a category. Everything is
/// local; nothing is sent anywhere.
enum IdeaCatalog {
    static let categories = ["Outdoors", "Fitness", "Creative", "Music", "Learning", "Food", "Social", "Relax"]

    private static let evening = 17 * 60..<22 * 60
    private static let morning = 8 * 60..<12 * 60
    private static let daytime = 9 * 60..<18 * 60

    static let all: [CatalogIdea] = [
        CatalogIdea(title: "Watch the sunset somewhere new", minutes: 45, category: "Outdoors", window: evening),
        CatalogIdea(title: "Explore a park you haven't been to", minutes: 90, category: "Outdoors", window: daytime),
        CatalogIdea(title: "Go on a bike ride", minutes: 60, category: "Outdoors"),
        CatalogIdea(title: "Have a picnic", minutes: 90, category: "Outdoors", window: daytime),

        CatalogIdea(title: "Try a yoga class", minutes: 60, category: "Fitness"),
        CatalogIdea(title: "Go for a run", minutes: 30, category: "Fitness"),
        CatalogIdea(title: "Swim some laps", minutes: 45, category: "Fitness"),
        CatalogIdea(title: "Go rock climbing", minutes: 120, category: "Fitness"),

        CatalogIdea(title: "Sketch something outside", minutes: 45, category: "Creative", window: daytime),
        CatalogIdea(title: "Take photos around town", minutes: 60, category: "Creative", window: daytime),
        CatalogIdea(title: "Try a pottery class", minutes: 120, category: "Creative"),
        CatalogIdea(title: "Paint something", minutes: 90, category: "Creative"),

        CatalogIdea(title: "Learn a new song", minutes: 30, category: "Music"),
        CatalogIdea(title: "Make a playlist for the week", minutes: 20, category: "Music"),
        CatalogIdea(title: "Go to a live show", minutes: 120, category: "Music", window: evening),

        CatalogIdea(title: "Start a new book", minutes: 45, category: "Learning"),
        CatalogIdea(title: "Do a free online lesson", minutes: 30, category: "Learning"),
        CatalogIdea(title: "Visit a museum", minutes: 120, category: "Learning", window: daytime),

        CatalogIdea(title: "Cook something new", minutes: 60, category: "Food", window: evening),
        CatalogIdea(title: "Try a new café", minutes: 45, category: "Food", window: daytime),
        CatalogIdea(title: "Bake something", minutes: 90, category: "Food"),
        CatalogIdea(title: "Go to the farmers market", minutes: 60, category: "Food", window: morning),

        CatalogIdea(title: "Call a friend you miss", minutes: 30, category: "Social"),
        CatalogIdea(title: "Grab coffee with someone", minutes: 45, category: "Social", window: daytime),
        CatalogIdea(title: "Host a game night", minutes: 120, category: "Social", window: evening),

        CatalogIdea(title: "Journal for a bit", minutes: 20, category: "Relax"),
        CatalogIdea(title: "Take a walk without your phone", minutes: 30, category: "Relax"),
        CatalogIdea(title: "Watch a movie you've been saving", minutes: 120, category: "Relax", window: evening),
    ]

    /// A few popular ones to start with, shown to people who haven't saved anything yet.
    static let starters: [CatalogIdea] = [
        "Go on a bike ride", "Cook something new", "Call a friend you miss", "Start a new book", "Try a yoga class",
    ].compactMap { title in all.first { $0.title == title } }

    /// Word beginnings that place an idea in a category ("hik" matches hike and hiking).
    private static let stems: [String: [String]] = [
        "Outdoors": ["hik", "trail", "walk", "park", "beach", "garden", "arboretum", "camp", "bik", "sunset", "picnic", "lake"],
        "Fitness": ["gym", "run", "yoga", "swim", "workout", "climb", "tennis", "basketball", "soccer", "lift", "pilates"],
        "Creative": ["paint", "draw", "sketch", "sew", "pottery", "craft", "knit", "photo", "write", "crochet"],
        "Music": ["guitar", "piano", "sing", "music", "concert", "band", "drum", "song", "playlist", "violin"],
        "Learning": ["read", "book", "learn", "course", "language", "podcast", "museum", "lesson", "study"],
        "Food": ["cook", "bak", "ramen", "restaurant", "cafe", "café", "coffee", "recipe", "boba", "pasta", "brunch", "market"],
        "Social": ["friend", "call", "party", "game night", "visit", "hang"],
        "Relax": ["movie", "nap", "meditat", "spa", "bath", "journal", "relax"],
    ]

    /// The category a title belongs to, recognized from its words, or nil when unclear.
    static func category(for title: String) -> String? {
        let words = SuggestionEngine.normalized(title).split(separator: " ").map(String.init)
        let text = words.joined(separator: " ")
        return categories.first { category in
            (stems[category] ?? []).contains { stem in
                stem.contains(" ") ? text.contains(stem) : words.contains { $0.hasPrefix(stem) }
            }
        }
    }

    static func ideas(in category: String) -> [CatalogIdea] {
        all.filter { $0.category.caseInsensitiveCompare(category) == .orderedSame }
    }

    static func item(forKey titleKey: String) -> CatalogIdea? {
        all.first { SuggestionEngine.normalized($0.title) == titleKey }
    }
}
