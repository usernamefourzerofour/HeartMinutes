# Heart Minutes

An iPhone and Apple Watch app that turns your heart rate into **Heart Minutes** – minutes of
moderate and vigorous activity, weighted like the American Heart Association recommends
(150 minutes of moderate *or* 75 minutes of vigorous activity per week).

The app reads heart rate, workouts and exercise minutes from Apple Health. It never writes to Health
and has no server – everything is calculated on your device.

## Features

- **Heart Minutes from heart-rate zones**: minutes in the moderate zone count 1×, minutes in the
  vigorous zone count 2×. Choose 2 zones (AHA, default) or the common 5 zones (Z0–Z5); limits and
  factors are adjustable. Max heart rate from your age (220 − age) or entered by hand.
- **Background activity filter**: daytime heart rate only counts when you are active – according to
  Apple Watch's activity flag, the Exercise ring, or both – optionally bridging short pauses.
- **Overview**: an animated heart ring for the period's progress toward your goal, a cumulative chart,
  a zone breakdown, a detailed heart-rate chart with zone bands and activity markers, and workouts.
- **Comparison**: optionally show Apple's Exercise minutes as a line next to your Heart Minutes.
- **Widgets**: Home Screen (small/medium/large with a chart), Lock Screen and StandBy.
- **Apple Watch app and complications**: heart ring and ring complications, minutes or percent.
- **38 languages**, including right-to-left.

## Building

Requirements: Xcode 27 (iOS 27 / watchOS 11 SDK) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
open Puls.xcodeproj
```

The project file is generated from `project.yml`. To run on your own devices, change
`bundleIdPrefix`, the bundle identifiers and the App Group (`group.dk.erik.puls`) in `project.yml`,
`Shared/ComplicationStore.swift` and `Puls/WidgetUpdater.swift` to ones in your own Apple developer account.

Run the tests:

```sh
xcodebuild test -project Puls.xcodeproj -scheme Puls -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Project layout

| Folder | Contents |
|---|---|
| `Puls/` | iPhone app: calculation (`ActiveMinutes.swift`), HealthKit (`HealthManager.swift`), views |
| `PulsWatch/` | Apple Watch app |
| `PulsWatchWidget/` | Watch complications |
| `PulsWidget/` | iPhone widgets |
| `Shared/` | Code shared between app, watch and widgets |
| `PulsTests/` | Unit tests |
| `Design/` | Scripts that draw the app icon |
| `Localization/` | All translations (`translations.json`) and the script that builds the String Catalog |
| `docs/` | Privacy policy, support page and App Store listing (GitHub Pages) |

## Sources

- American Heart Association – [Target Heart Rates](https://www.heart.org/en/healthy-living/exercise-and-physical-activity/fitness-basics/target-heart-rates)
- American Heart Association – [Recommendations for Physical Activity in Adults](https://www.heart.org/en/healthy-living/fitness/fitness-basics/aha-recs-for-physical-activity-in-adults)

Heart Minutes is not a medical device and does not give medical advice.

## License

[MIT](LICENSE)
