import SwiftUI

@main
struct MaybeCalendarApp: App {
    @State private var store: Store

    init() {
        let store = Store()
        if ProcessInfo.processInfo.arguments.contains("-demoData") {
            store.loadDemoData()
        }
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

    var body: some View {
        TabView(selection: $tab) {
            CalendarView(selectedDay: $selectedDay)
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(AppTab.calendar)
            IdeasView(selectedDay: $selectedDay, tab: $tab)
                .tabItem { Label("Ideas", systemImage: "lightbulb") }
                .tag(AppTab.ideas)
                .badge(store.ideas.count)
        }
    }
}
