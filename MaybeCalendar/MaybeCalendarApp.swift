import SwiftUI
import TipKit

@main
struct MaybeCalendarApp: App {
    @State private var store: Store

    init() {
        let store = Store()
        // Only in builds run from Xcode, so a public build can never replace someone's data.
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-demoData") {
            store.loadDemoData()
        }
        if arguments.contains("-hideTips") {
            Tips.hideAllTipsForTesting()
        }
        #endif
        // A single tip, shown once, so there's no need to space tips out.
        try? Tips.configure([.displayFrequency(.immediate)])
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}

enum AppTab: Hashable {
    case calendar, ideas
}

struct ContentView: View {
    @Environment(Store.self) private var store
    @State private var tab = AppTab.calendar
    @State private var selectedDay = Date.now
    @State private var focusDate: Date?

    var body: some View {
        TabView(selection: $tab) {
            CalendarView(selectedDay: $selectedDay, focusDate: $focusDate)
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(AppTab.calendar)
            IdeasView(selectedDay: $selectedDay, focusDate: $focusDate, tab: $tab)
                .tabItem { Label("Ideas", systemImage: "lightbulb") }
                .tag(AppTab.ideas)
                .badge(store.ideas.count)
        }
    }
}
