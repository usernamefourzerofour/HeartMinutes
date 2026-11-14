# CLAUDE.md

Guidance for Claude working on Heart Minutes, an iPhone + Apple Watch app (Swift, SwiftUI, Swift Charts, WidgetKit, HealthKit).

## Working with Erik

- Talk to Erik in Danish unless he writes in English. Code, code comments, commit messages, README and docs are always in English.
- Keep answers short and clear. Say what an action costs before doing it (see NoMac below).
- Plan and write code first. Only start a Mac when there is something to build, and ask Erik first.
- Never put keys or passwords in the code or the repo.
- After every build: summarise errors and warnings briefly and suggest the next step.
- Erik prefers few widgets (settings instead of extra widgets); widgets simple and clean, the app has the details.

## Project layout

| Path | Contents |
| --- | --- |
| `project.yml` | XcodeGen spec. The `.xcodeproj` and all `Info.plist` files are generated from it. |
| `HeartMinutes/` | iPhone app: calculation (`ActiveMinutes.swift`, `HeartZones.swift`), HealthKit (`HealthManager.swift`), views. |
| `HeartMinutesWatch/` | Apple Watch app. |
| `HeartMinutesWatchWidget/` | Watch complications. |
| `HeartMinutesWidget/` | iPhone widgets (Home Screen, Lock Screen, StandBy). |
| `Shared/` | Used by all targets: complication data store, ring drawing (`WidgetCore.swift`), `Brand.swift`, translations, privacy manifest. |
| `HeartMinutesTests/` | Unit tests and a ring render test. |
| `Localization/` | `translations.json` + `build_catalog.py` (see below). |
| `docs/` | Privacy policy, support page, App Store listing draft (GitHub Pages: `/docs`). |

Names: the app, targets, scheme and project are **Heart Minutes** / `HeartMinutes`. The bundle IDs keep the old name
(they are tied to the app in App Store Connect): `dk.erik.puls`, `.watchkitapp`,
`.watchkitapp.widget`, `.widget`; App Group `group.dk.erik.puls`. iPhone only (no iPad).

## Localisation

- English is the development language. User-facing strings are English keys in `Shared/Localizable.xcstrings`;
  the Health permission texts are in `HeartMinutes/InfoPlist.xcstrings` and `HeartMinutesWatch/InfoPlist.xcstrings`.
- 37 translations plus English (`CFBundleLocalizations` in `project.yml`), the same set as WeekPeek.
- `Localization/translations.json` is the source of truth: English text with `{0}`, `{1}` placeholders → translations
  (plural dicts for count-dependent texts). After building, export the keys Xcode extracted and run
  `python3 Localization/build_catalog.py keys.json Localization/translations.json Shared/Localizable.xcstrings`.
  Any key it reports as UNMATCHED needs a translation entry.
- Strings returned as `String` (titles, explanations) must use `String(localized:)`; `Text("…")` literals are extracted automatically.
- Right-to-left (ar, he): wrap number ranges in Unicode isolates (`⁦…⁩`).
- Tests compare Danish texts, so they run with `-testLanguage da`.

## Building and testing with NoMac

All Xcode work runs on a NoMac cloud Mac ($0.90 per hour, billed per minute). Ask Erik before starting one; always stop it,
also after a failure. The project lives in `~/drive/src/HeartMinutes` on the Mac's drive.

Getting code onto the Mac: tar the changed files, `create_mac_link` (upload to `~/drive/src/bNN.tgz`), `curl -T` the file to the
upload URL, then `get_mac_file_link` to place it, and extract it in `~/drive/src/HeartMinutes`. Verify with a combined sha256 of all
`.swift` files on both sides.

```sh
cd ~/drive/src/HeartMinutes && xcodegen generate -q
SIM=$(xcrun simctl list devices available | grep -m1 iPhone | grep -oE '[0-9A-F-]{36}')
xcodebuild test -project HeartMinutes.xcodeproj -scheme HeartMinutes -destination "id=$SIM" -testLanguage da -resultBundlePath build/test.xcresult -quiet
xcodebuild archive -project HeartMinutes.xcodeproj -scheme HeartMinutes -destination 'generic/platform=iOS' -archivePath build/HeartMinutes.xcarchive \
  -xcconfig "$HOME/.nomac/signing/BYNRN8J29U.xcconfig" CURRENT_PROJECT_VERSION=NN -quiet
xcodebuild -exportArchive -archivePath build/HeartMinutes.xcarchive -exportPath build/export \
  -exportOptionsPlist "$HOME/.nomac/signing/BYNRN8J29U.ExportOptions.plist"
```

Then `send_to_testflight` with `/Users/agent/drive/src/HeartMinutes/build/export/HeartMinutes.ipa` (encryption: false) and short notes.
NoMac project id: `prj_0ypElAJaL7Nljm9Msz7g7`. Bump `CURRENT_PROJECT_VERSION` in `project.yml` for every build.

## App Store

See `docs/app-store.md`. Lessons from WeekPeek: set country availability (all countries) by hand; the age rating needs
`socialMedia`; App Review may ask for a screen recording from a device (Guideline 2.1); metadata can't be changed through
NoMac once a version is READY_FOR_REVIEW. HealthKit apps need a privacy policy and must not make medical claims.

## Commits

Commit messages in English, imperative mood.
