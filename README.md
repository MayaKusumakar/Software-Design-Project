# Maybe Calendar

A personal iOS calendar for keeping track of both the plans you've committed to **and** the ones you might do. Tentative plans live on a separate "potential" layer you can show or hide, and a dateless **Ideas** list holds free-time activities until you're ready to put them on the calendar.

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
To see the app filled in right away, edit the scheme (**Product → Scheme → Edit Scheme… → Run → Arguments**) and add `-demoData` under *Arguments Passed On Launch*. This **replaces** any saved data with a few sample events and ideas. Remove the argument afterwards so your own data isn't overwritten on the next launch.

## Using the app

The app has two tabs: **Calendar** and **Ideas**.

### Try the core features in one minute
1. On the **Calendar** tab, tap an empty hour and save an event as **Confirmed**: it appears as a solid block.
2. Tap another hour, set the status to **Potential**, and save: it appears as a dashed, see-through block.
3. Tap the **Potential shown** button under the week strip to hide potential plans, then tap it again to bring them back.
4. Tap the **⊕** on the dashed block to commit to it: it turns solid.
5. Go to the **Ideas** tab, add an idea, and tap **Schedule**. Save it, and the app jumps back to the calendar with the idea placed as a potential plan.

### Calendar tab
- **Pick a day** from the week strip at the top. Use the arrows (or swipe the strip) to change weeks, and **Today** to jump back.
  - A filled dot under a day means it has confirmed plans; a hollow dot means it has potential plans.
  - The day view opens at the current time for today, or at the first plan for other days.
- **Add an event:** tap **+** in the top-right, or tap any empty hour in the timeline to start an event at that time.
- **Edit or delete an event:** tap it. The editor lets you change the title, date, start/end time, status, and notes, and has a **Delete Event** button.
- **Confirmed vs. potential:** every event has a status.
  - **Confirmed** events are solid blue blocks.
  - **Potential** events are transparent with a dashed border.
- **Commit to a potential plan:** tap the **⊕** button on its block. It becomes confirmed immediately.
- **Show / hide potential plans:** tap the eye button under the week strip (**Potential shown** / **Potential hidden**). While hidden, it shows how many potential plans are hidden on that day. The setting is remembered.
- Overlapping events are placed side by side so you can compare options for the same time slot.

### Ideas tab
- **Add an idea:** type an activity (e.g. "Try the new ramen place") and tap **Add**. Ideas have no date.
- **Schedule an idea:** tap **Schedule**. The event editor opens with the title filled in and the status set to **Potential**. Pick a date and time and tap **Save**, and the app switches to the Calendar tab and scrolls to the new plan.
  - By default the idea is removed from the list once scheduled. Turn on **Keep in my ideas list** for things you do repeatedly.
- **Remove an idea:** swipe left on it and tap **Delete**.

### Saving
Everything is saved automatically on the device (a JSON file in the app's Documents folder), so your plans are still there after you close and reopen the app.

## Project structure

| File | What it does |
| --- | --- |
| `MaybeCalendar/MaybeCalendarApp.swift` | App entry point and the two-tab layout |
| `MaybeCalendar/Store.swift` | Data models (`PlanEvent`, `Idea`) and saving/loading |
| `MaybeCalendar/CalendarView.swift` | Week strip, day timeline, event blocks, overlap layout |
| `MaybeCalendar/EventEditorView.swift` | Add / edit / delete / schedule-idea form |
| `MaybeCalendar/IdeasView.swift` | Ideas list |

## Not included (by design)
Shared calendars, invitations, other integrated services, multiple accounts, tasks/to-dos, and recurring events are left out to keep the focus on personal scheduling and tentative plans.

## Other coursework
- [Homework 1 – App proposal](Homework1/HW1.md)
