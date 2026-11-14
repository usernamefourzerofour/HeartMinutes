# App Store screenshots

Made on a Mac with the Simulators and the demo week (`-DemoData YES`, see `HeartMinutes/DemoData.swift`).

1. iPhone 17 Pro Max Simulator, clean status bar (`xcrun simctl status_bar … override --time 9:41`), app launched with
   `-DemoData YES -AppleLanguages '(en)' -AppleLocale en_US`. Screenshots (`xcrun simctl io … screenshot`):
   `raw-1.png` Overview, `raw-2.png` scrolled down with Monday's run tapped, `raw-3.png` Settings, `raw-4.png` Overview in
   dark mode. `raw-2c.png` is `raw-2.png` with the top 290 px taken from `raw-3.png` (hides content under the status bar).
2. Apple Watch Ultra 3 Simulator (watchOS runtime: `xcodebuild -downloadPlatform watchOS`), watch app launched with the
   same arguments: `watch-1.png` (top) and `watch-2.png` (scrolled to the chart). These are uploaded as they are.
3. `python compose.py SHOTS OUT` and `python compose_watch.py SHOTS OUT` (Pillow) make the five iPhone screenshots
   (1320 × 2868): `1-week`, `2-workouts`, `3-zones`, `4-watch`, `5-private`.
