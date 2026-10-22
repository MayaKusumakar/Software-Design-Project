# User Testing Writeup

| | 5-second test | Where they got stuck/suggestions | Difficulty | Magic Wand (one fix) | App description in one sentence |
| --- | --- | --- | --- | --- | --- |
| P1 | “A calendar app” | Tapping and holding a time on the calendar did not successfully pull up an event to be created at that time | 1 | Ability to import current “Google Calendar” or “Apple Calendar” into the app | “An app to help you be more productive with your free time” |
| P2 | “A tool for planning your life and your schedule” | Wanted to plan an app for 11 PM to midnight, but the app wouldn’t allow it<br><br>Switching between weeks and months | 1 | “Have a larger arrow on the side to switch weeks and then like a single arrow to switch days”<br><br>“Visual cues to make it a bit more mindless, like bolding certain things or certain coloring designs” | “A planning app” |
| P3 | “A calendar app” | Adding ideas to the existing calendar (didn’t autofill the title), rescheduling ideas (wanted to drag it up/down), and unadding these ideas<br><br>Idea got scheduled for 8:05 automatically instead of 8 PM<br><br>Idea doesn’t schedule if it overlaps with another event, even if the user wants it to | 4 | Swipe to change days. Left swipe: tomorrow, right swipe: yesterday | “Calendar with scheduling system built in” |
| P4 | Calendar app with an ideas tab– looks like it finds free time slots to add activities | Had trouble adding ideas to the list, and scheduling these ideas was not Straightforward<br><br>Wasn’t sure how to minimize the keyboard<br><br>All ideas weren’t showing up, and he wasn’t sure why | 2-3 | Gestures:<br>Wants to be able to see a list of ideas or swipe through them<br>Wants to be able to swipe through days/weeks<br><br>Custom time blocks:<br>Wants to be able to set a custom time block for each idea instead of only preset am/pm/noon | “A calendar app that stores and helps you schedule potential plans” |
| P5 | “A calendar” | Struggled to distinguish scheduling potential plans from real ones<br><br>Struggled switching between potential and confirmed plans<br><br>Struggled to add an idea<br><br>Suggestion: Be able to add ideas from the plus tab as well | 2 | “A way for the app to identify what my interests are. Instead of me manually inputting my own ideas, the app starts suggesting ideas based off my own interests. Can see ideas laid out in the next few weeks/months. “ | “A more organized calendar with your own ideas and potentially ideas that it could create for you” |

## Patterns

**People want the actual schedule page to be more interactive (3/5 people)**
- P1 tapped and held for a time to add an event, and it didn’t work for them
- P3 and P4 want to be able to drag ideas across the calendar

**Ideas and calndar are too separated (4/5 people)**
- P2 ignored the suggestion card with the option to add it to the calendar, and went to ideas and pressed “schedule” from there instead
- P3 wanted to drag ideas onto the calendar and be able to drag ideas around to move them around the schedule for different times
- P3, P4, and P5 pressed the plus button at first to make a new idea

**Moving between days/weeks/months can be improved and more accessible (4/5 people)**
- P2, P3, P4, P5 wanted a month/year/day view option and better navigation between them
- P3 wanted a swiping feature to swipe between the days quickly and easily

**Small bugs still exist: (4/5 people)**
- P3 couldn’t “undo an idea becoming a plan”,
- An idea isn’t allowed to overlap with another set plan, even if the user wants it to be
- New ideas start at :05 instead of the hour if another event ends on the hour.
- P2 was not able to schedule something from 11 PM to midnight.
- P1 was not able to tap and hold on a time slot to schedule an event
- P4 was not able to cycle through all of the ideas

## What I would change in the app based on results

**Make ideas and calendar more intertwined and more interactive:**
- Add a small box of ideas that can be min/maximized that has a list of ideas to drag onto calendar
- A “move back to ideas option” on any plan that came from an idea
- The plus button on the main page should have an “add ideas” tab and an “add event tab”
- Make ideas more customizable (custom time block, custom category)
- Make the ideas more involved and have the app learn about the person and their interests and suggest more than just their own ideas (maybe historical repeats or tailored new ideas)

**Make the calendar timeline more interactive to touch**
- Press & holding or tapping a time slot should open up a new event for that hour block
- Drag a plan to move it along different times
- Drag the bottom edge of an event to change the length of time of the event

**Moving between days/weeks:**
- Swipe the day left or right on today’s screen to go to tomorrow or yesterday’s calendar
- Add bigger, more obvious arrows to switch between different days and weeks
- Add a month/year view display, which happens when you click on the month name
