# App Store listing (draft)

Working notes for the App Store Connect listing. English (en-US) is the primary language; the translations for all app
languages are in `Localization/app-store.json`. All 36 languages App Store Connect supports were filled in on
15 November 2026 (not `bg` and `lt`, which it doesn't offer).

## Basics

| Field | Value | Limit |
| --- | --- | --- |
| Name | Heart Minutes | 30 |
| Subtitle | Heart rate zones, weekly goal | 30 |
| Category | Health & Fitness | |
| Price | Free (no in-app purchases, no ads) | |
| Privacy Policy URL | `https://usernamefourzerofour.github.io/HeartMinutes/privacy` | |
| Support URL | `https://usernamefourzerofour.github.io/HeartMinutes/` | |
| Copyright | 2026 Erik Bouvin Poulsen | |

## Promotional text (170 characters)

> Workouts count – and so does everything in between: Apple Watch measures your heart rate in the background, so brisk walks and bike rides are logged automatically.

## Keywords (100 characters, comma-separated, no spaces)

```
heart rate,zones,cardio,AHA,150 minutes,weekly goal,fitness,activity,pulse,workout,complication
```

## Description (4000 characters)

> Heart Minutes turns the heart rate from your Apple Watch into one simple number: the minutes you spend in your heart rate zones, weighted the way the American Heart Association recommends. Moderate minutes count once, vigorous minutes count twice, and the goal is 150 a week.
>
> WORKOUTS + EVERYDAY ACTIVITY
> • Workouts: every workout counts, with its heart rate and zones in detail.
> • Everyday activity: your Apple Watch measures your heart rate in the background all day, and Heart Minutes logs it automatically. A brisk walk, cycling to work or taking the stairs counts – without starting a workout.
>
> ON YOUR WRIST AND HOME SCREEN
> • Apple Watch app with heart ring and ring complications
> • Home Screen, Lock Screen and StandBy widgets
> • Today, this week, this month or a rolling period
>
> SEE YOUR WEEK AT A GLANCE
> • An animated heart ring that fills toward your goal and keeps going past 100 %
> • A chart of how your minutes added up, split into background activity and workouts
> • How the minutes are spread across your zones, and the calculation behind them
> • A detailed heart rate chart with your zones, workouts and activity
>
> YOUR ZONES, YOUR RULES
> • 2 zones (AHA) or the common 5 zones (Z0–Z5)
> • Max heart rate from your age or entered by hand
> • Adjustable zone limits and how much each zone counts
> • Choose whether everyday heart rate only counts when you're active
>
> PRIVATE BY DESIGN
> Heart Minutes only reads from Apple Health. It never writes to Health, has no servers, no accounts, no analytics and no tracking. Everything is calculated on your iPhone and Apple Watch.
>
> NOT A MEDICAL DEVICE
> Heart Minutes is for general fitness and wellness. It does not diagnose, treat or prevent any condition.
>
> AN HONEST NOTE
> Heart Minutes is a free hobby project, "vibe coded" with the help of AI (Claude by Anthropic) and maintained in spare time. It is not made to earn money: no ads, no in-app purchases, no subscriptions.
>
> The full source code is open under the MIT license on GitHub. Feedback, translation fixes and ideas are very welcome there.

## App Review notes

> Heart Minutes reads heart rate, workouts and Exercise minutes from Apple Health (read-only) and shows weekly "Heart Minutes": minutes in moderate (× 1) and vigorous (× 2) heart rate zones per the American Heart Association. To test: open the app on an iPhone paired with an Apple Watch that has heart rate data, allow Health access, and look at the Overview tab. Widgets and the watch app show the same number. No account or login is needed. The app makes no network requests and does not write to Health. It is not a medical device.

## App Privacy ("nutrition label")

**Data Not Collected.** Matches `Shared/PrivacyInfo.xcprivacy` (no tracking, no collected data; UserDefaults reasons `CA92.1` and `1C8F.1`).

## Age rating

All content questions: **None / No** (include `socialMedia`). Expected result: **4+**. Erik confirms the answers.

## EU trader status (DSA)

**Non-trader** (same as WeekPeek): free, no ads, no purchases.

## Screenshots

Made with the demo week (`-DemoData YES`) in the Simulators; how is described in `tools/screenshots/README.md` and
`tools/screenshots/compose.py`.

- iPhone 6.9" (1320 × 2868), headline on a soft pink background (version 1.0.2):
  1. Always in view (the widget page with the large, medium and small widget) · 2. On your wrist (the watch face with
  the heart and ring complications, and the watch app) · 3. Workouts + everyday activity · 4. Every workout in detail ·
  5. Your zones, your rules · 6. Private by design (dark mode)
- Apple Watch Ultra (`APP_WATCH_ULTRA`, 422 × 514): the watch app's heart ring.
