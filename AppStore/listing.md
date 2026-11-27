# App Store listing: Maybe Calendar 1.0

Everything to paste into App Store Connect, field by field. Character limits are Apple's, and every field here fits.

## App information

| Field | Value |
| --- | --- |
| Name (30) | Maybe Calendar |
| Backup names if it's taken | Maybe Calendar: Free Time · Maybe Calendar – Plan Maybes |
| Subtitle (30) | Make time for what you want |
| Bundle ID | com.mayakusumakar.maybecalendar |
| SKU (any unique text) | maybecalendar-ios |
| Primary category | Productivity |
| Secondary category | Lifestyle |
| Price | Free |
| Copyright | 2026 Maya Kusumakar |
| Privacy Policy URL | Link to `AppStore/privacy-policy.md` on GitHub (repo must be public) |
| Support URL | https://github.com/MayaKusumakar/Software-Design-Project |

## Promotional text (170)
Your free time, filled with things you actually want to do. Save ideas without a date, and Maybe Calendar suggests them when a gap in your day opens up.

## Description (4000)
Maybe Calendar is a calendar for the plans you've committed to and the ones you might do. It also helps you make time for the things you keep meaning to get to.

FREE TIME, FILLED FOR YOU
Save ideas with no date attached: try the new ramen place, practice guitar, hike that trail. Maybe Calendar finds the open gaps in your day and suggests ideas that fit, right on the timeline. Tap + to add one, or tap it to see every option for that free time.

PLANS AND MAYBES
Confirmed plans are solid. Maybes are see-through with a dashed border, so you can see what's set and what's still open. Commit to a maybe with one tap. Hide all maybes when you only want to see what's certain.

SUGGESTIONS THAT MAKE SENSE
• Only real free time between 8 AM and 10 PM, never time that has already passed
• Only ideas that fit the gap and the time of day you set for them
• Your own ideas come first
• Learns the free-time things you do often, like an evening walk, and never suggests classes, work or meetings
• A few new ideas related to what you like, such as other outdoor activities if you save a hike
• Say "Not now" and it waits before suggesting that again

EASY TO CHANGE
• Press and hold a plan to drag it to a new time
• Drag its bottom edge to make it longer or shorter
• Drag an idea from the tray onto the day
• Undo a one-tap add
• Move a plan back to your ideas if it doesn't work out

PRIVATE BY DESIGN
No account, no ads and no tracking. Everything stays on your iPhone, and suggestions are worked out on the device.

## Keywords (100)
planner,schedule,free time,ideas,tentative,plans,habits,suggestions,student,agenda,bucket list

## Screenshots (iPhone 6.9", 1320 × 2868)
Upload in this order from `AppStore/screenshots/`. Apple scales them down for smaller iPhones.

1. `1-day.png`: a day with plans, maybes and suggestions in the free time
2. `2-free-time.png`: every option for one free gap
3. `3-ideas-tray.png`: the ideas tray, showing where each idea fits
4. `4-month.png`: the month view
5. `5-ideas.png`: the Ideas list

## Header and Search Results artwork (optional)
On the version page, open **App Previews and Screenshots → Header and Search Results** and upload from `AppStore/creative/`:

| Tab | File | Size |
| --- | --- | --- |
| Header | `header.png` | 3840 × 1646 (21:9) |
| Search Results | `search.png` | 3840 × 2560 (3:2) |

Both are PNGs with no transparency. The headline ("Plans, maybes, and everything in between") and the day card sit inside Apple's art safe area for each size, so they stay fully visible however the App Store crops the image. The shapes around them are decoration and may be cropped. If App Store Connect offers "Use header asset in search results", leave it off so search uses its own image. These placements show on iOS 27 and later.

The artwork follows Apple's creative asset rules: a short phrase, suitable for 4+, no prices, URLs, awards or Apple devices, and no SF Symbols or emoji (the icons are drawn by hand). The text is English, so add localized versions if the app adds languages.

## Age rating
Answer **None** or **No** to every question. The app has no user-generated content shared with others, no messaging, no web browsing, no ads and no purchases. The result should be **4+**.

## App Privacy
Choose **"No, we do not collect data from this app"**. The label will read **Data Not Collected**. This matches the privacy manifest in the app (`PrivacyInfo.xcprivacy`).

## Export compliance
Already answered in the build (`ITSAppUsesNonExemptEncryption = NO`), so App Store Connect won't ask.

## App Review information
- **Sign-in required:** No
- **Notes:**
  > No account or sign-in. The app starts empty and keeps all data on the device; it makes no network requests.
  > To see Smart Suggestions: open the Ideas tab, type an idea (for example "Go for a walk") and tap Add. Go back to the Calendar tab. Yellow dotted blocks appear in the free time of today (between 8 AM and 10 PM, only time that hasn't passed) and of the following days. Tap the + on one to add it as a "maybe" plan, or tap the block to see all options for that free time. Press and hold a plan to move it.
- **Contact:** your name, phone and email (only Apple sees these)

## Version
1.0 (build 1). For each new upload, raise the build number in Xcode (target → General → Build).
