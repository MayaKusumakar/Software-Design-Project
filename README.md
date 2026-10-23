# Maybe Calendar

A personal iOS calendar for keeping track of both the plans you've committed to **and** the ones you might do, and for actually making time for the things you want to do. Tentative plans live on a separate "potential" layer you can show or hide, a dateless **Ideas** list holds activities you want to make time for, and **Smart Suggestions** finds your free time and fills it with ideas that fit.

Built natively in Swift with SwiftUI.

<img src="docs/calendar.png" alt="Calendar day view with confirmed and potential plans" width="300">

## Building the app

**Requirements:** a Mac with **Xcode 27**. No third-party packages or extra setup are needed.

1. Clone the repository:
   ```bash
   git clone https://github.com/MayaKusumakar/Software-Design-Project.git
   cd Software-Design-Project
   ```
2. Open `MaybeCalendar.xcodeproj` in Xcode.
3. In the toolbar, pick the **MaybeCalendar** scheme and an iPhone simulator (for example **iPhone 17**).
4. Press **⌘R** (Product → Run). The app builds and launches in the simulator.

To run on a physical iPhone instead, select the **MaybeCalendar** target → **Signing & Capabilities**, choose your Apple ID team, and change the bundle identifier if Xcode asks.

Building from the command line also works:
```bash
xcodebuild -project MaybeCalendar.xcodeproj -scheme MaybeCalendar -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### Optional: start with sample data
To see the app filled in right away, edit the scheme (**Product → Scheme → Edit Scheme… → Run → Arguments**) and add `-demoData` under *Arguments Passed On Launch*. This **replaces** any saved data with a few sample events, ideas, and past evening walks (so Smart Suggestions has some history to learn from). Run it before about 7 PM: suggestions only cover free time between 8 AM and 10 PM that hasn't passed yet. Remove the argument afterwards so your own data isn't overwritten on the next launch.

## Using the app

The app has two tabs: **Calendar** and **Ideas**. The calendar is built around your free time: it shows suggestions right inside the open gaps of your day, and your saved ideas sit in a tray at the bottom, ready to drag onto a time.

### Try the core features in one minute
1. On the **Calendar** tab, look for the yellow dotted blocks in the free gaps of your day. Each one is a suggestion from your saved ideas.
2. Tap the **+** on a suggestion to add it as a potential (maybe) plan. Tap **Undo** if you change your mind.
3. Tap a suggestion itself to see everything that fits that free time, including new ideas related to what you've saved.
4. Open the **Your ideas** tray at the bottom, then press and hold an idea and drag it onto a time.
5. Press and hold a plan and drag it to move it. Drag its bottom edge to make it longer or shorter.
6. Tap the **⊕** on a dashed (potential) plan to commit to it: it turns solid.
7. Swipe the day left or right to change days, or tap the month name to see the whole month or year.

### Calendar tab
- **Moving around:** use the double arrows **«  »** to change weeks and the single arrows **‹ ›** next to the date to change days. You can also swipe the day sideways. **Today** jumps back. Tap the month name for a **month** and **year** view.
  - Under each day: a filled dot means confirmed plans, a hollow dot means potential plans, and a yellow dot means there's a free-time idea that fits.
- **Add a plan:** tap or press and hold an empty time (top half of an hour starts on the hour, bottom half on the half hour). Or use **+ → New Event**.
- **Edit, move or resize a plan:** tap it to edit. Press and hold it, then drag, to move it. Drag the small handle at its bottom edge to change when it ends.
- **Confirmed vs. potential:** the editor asks *Is this happening for sure?*
  - **Confirmed** plans are solid blue blocks.
  - **Potential** plans (maybes) are see-through with a dashed border. Tap the **⊕** on one when it's happening.
- **Show / hide potential plans:** tap the eye button. While hidden, it shows how many are hidden that day. The setting is remembered.
- **Move Back to Ideas:** any potential plan, or plan that came from an idea, has a **Move Back to Ideas** button in its editor.
- Overlapping plans are placed side by side so you can compare options. The editor tells you when a plan overlaps another one, but still lets you save it.
- Plans can end at midnight (for example 11 PM–12 AM).

### Smart Suggestions
The app finds your free time and suggests something you'd actually want to do with it.
- **On the timeline:** suggestions appear as yellow dotted blocks inside the free gaps, with the activity, its time and length, and a short reason such as *From your Ideas · fits your 60-min break*, *You often plan this in the evening*, or *New idea · because you saved Hike Stevens Trail*.
- **One-tap add:** the **+** on a suggestion adds it as a potential plan. An **Undo** bar appears for a few seconds.
- **All the options:** tap a suggestion to open that free time. It lists everything that fits, your own ideas and habits first, then up to three new ideas. Tap **Add**, or tap a row to change its time first. Swipe left for **Not now** (or **Save idea** on a new one). It also says how many of your ideas don't fit, so missing ones aren't a mystery.
- **Not now** hides that activity for a day. If you keep saying not now, it waits longer (3 days, then a week).

How it picks:
- **Only real free time.** It looks between 8 AM and 10 PM, skips time that has passed, and counts potential plans as busy. Gaps shorter than 30 minutes are ignored. Suggestions start on the hour or quarter hour.
- **Only what fits.** An activity is never suggested for a gap it doesn't fit in, or outside the time block you set for it. Ideas with no length are treated as about an hour.
- **Your ideas first.** Saved ideas rank above anything learned from history. Ideas you've accepted before, ideas that match your usual times, and ideas that have waited a few weeks get a small boost. Ideas already on that day's calendar are skipped.
- **Careful with history.** Something counts as a habit only if you planned it on at least 3 different days in the last 2 months, and only if it was clearly free time: scheduled from an idea or suggestion, or saved as potential. Classes, meetings, work and appointments are never suggested. A habit is only suggested at the time of day you usually do it.
- **New ideas from your interests.** The app recognizes the kind of thing you like from your ideas' categories (or their wording, like "hike" → Outdoors) and suggests a few related activities from a built-in list. It never invents interests: with no ideas or history, it suggests nothing and offers starter ideas instead.
- **Not overwhelming.** Only the next two free gaps of a day get a suggestion, each with a different activity. Similar ideas take turns from day to day.

### Ideas
- **Add an idea:** **+ → New Idea** on the calendar, the **+** in the ideas tray, or type one on the **Ideas** tab and tap **Add**. Ideas have no date.
- **Ideas tray:** at the bottom of the calendar. Each idea shows how long it takes and where it first fits that day (*Fits 3:30 PM* or *No room this day*). Tap one to schedule it at that time, or press and hold and drag it onto the timeline. Tap **⌄** to shrink the tray to one line.
- **Edit an idea:** tap it on the **Ideas** tab to set (all optional):
  - **Takes about:** how long it takes.
  - **When:** any time, morning, afternoon, evening, or **custom times** (for example 6–8 PM). Suggestions stay inside this window.
  - **Category:** pick one or type your own. A category is suggested from the title.
  - **I do this regularly:** keeps the idea in your list after you schedule it.
  - **Notes.**
- **Schedule an idea:** tap **Schedule** on the Ideas tab. The editor opens at the first free time that fits. By default the idea leaves the list once scheduled; turn on **Keep in my ideas list** for things you do repeatedly.
- **Remove an idea:** swipe left on it and tap **Delete**.

### Saving
Everything is saved automatically on the device (a JSON file in the app's Documents folder), so your plans are still there after you close and reopen the app. This includes what you accepted or dismissed from Smart Suggestions. Nothing is sent anywhere; suggestions are worked out on the phone. Data saved by earlier versions of the app still loads.

## Running the tests
In Xcode, press **⌘U** (Product → Test). The 54 tests cover free-time detection (overlaps, events past midnight, daylight-saving days, quarter-hour starts), time blocks, ranking, cooldowns, learning from history, new-idea suggestions, plans ending at midnight, one-tap add and undo, moving and resizing plans, Move Back to Ideas, and loading data saved by older versions. From the command line:
```bash
xcodebuild test -project MaybeCalendar.xcodeproj -scheme MaybeCalendar -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Project structure

| File | What it does |
| --- | --- |
| `MaybeCalendar/MaybeCalendarApp.swift` | App entry point and the two-tab layout |
| `MaybeCalendar/Store.swift` | Data models (`PlanEvent`, `Idea`), saving/loading, add/undo/move actions |
| `MaybeCalendar/CalendarView.swift` | Week strip, day timeline, suggestions, dragging and resizing plans |
| `MaybeCalendar/MonthYearView.swift` | Month and year views |
| `MaybeCalendar/EventEditorView.swift` | Add / edit / delete / schedule-idea form |
| `MaybeCalendar/IdeasView.swift` | Ideas tab |
| `MaybeCalendar/IdeaEditorView.swift` | Add / edit one idea (length, time block, category, regular) |
| `MaybeCalendar/Suggestions.swift` | Smart Suggestions engine: free time, habits, interests, ranking |
| `MaybeCalendar/IdeaCatalog.swift` | Built-in activities and category recognition for new ideas |
| `MaybeCalendar/SuggestionViews.swift` | Suggestions on the timeline, the free-time sheet, the ideas tray, Undo |
| `MaybeCalendarTests/` | Unit tests for the engine and saving |

## Not included (by design)
Shared calendars, invitations, other integrated services, multiple accounts, tasks/to-dos, and recurring events are left out to keep the focus on personal scheduling and tentative plans.

## Other coursework
- [Homework 1 – App proposal](Homework1/HW1.md)
