import SwiftUI

/// Settings: the most important ones here, the rest under "Advanced". A setting changed from its default gets a ↺
/// button that resets it.
struct SettingsView: View {
    @Environment(HealthManager.self) private var health
    @State private var confirmResetAll = false

    private typealias D = HealthManager.Defaults

    var body: some View {
        @Bindable var health = health
        NavigationStack {
            Form {
                // At the top: measurements decide what counts in the heart rate calculation.
                Section {
                    ResetRow(changed: health.includeBackground != D.includeBackground, info: String(localized: "Heart rate measured during the day outside workouts – usually by Apple Watch, but also by other devices that save heart rate in Health. Turn off to see and count only workouts.")) {
                        health.includeBackground = D.includeBackground
                    } content: {
                        Toggle(isOn: $health.includeBackground) {
                            Label("Background measurements", systemImage: "applewatch")
                        }
                        .tint(HeartChart.backgroundColor)
                    }
                    ResetRow(changed: health.includeWorkouts != D.includeWorkouts, info: String(localized: "Heart rate measured during a recorded workout.")) {
                        health.includeWorkouts = D.includeWorkouts
                    } content: {
                        Toggle(isOn: $health.includeWorkouts) {
                            Label("Workouts", systemImage: "figure.run")
                        }
                        .tint(HeartChart.workoutColor)
                    }
                } header: {
                    Text("Measurements")
                } footer: {
                    Text("Which heart rate measurements count towards Heart Minutes and are shown in the heart rate chart.")
                }

                Section {
                    ResetRow(changed: health.weeklyGoal != D.weeklyGoal, info: String(localized: "Your weekly goal. The AHA recommends at least 150 min of moderate or 75 min of vigorous activity per week. The goal is scaled to the selected period, e.g. about 21 min for one day.")) {
                        health.weeklyGoal = D.weeklyGoal
                    } content: {
                        Stepper(value: $health.weeklyGoal, in: 10...1000, step: 10) {
                            Text("Goal: \(health.weeklyGoal) min per week")
                        }
                    }
                    ResetRow(changed: health.activityMode != D.activityMode || health.pauseSeconds != D.pauseSeconds,
                             info: String(localized: "When your heart rate during the day (outside workouts) counts:") + "\n\n" + ActiveMinutes.ActivityMode.allCases.map { "• \($0.title): \($0.explanation)" }.joined(separator: "\n") + "\n\n" + String(localized: "Measurements during workouts always count.")) {
                        health.activityMode = D.activityMode
                        health.pauseSeconds = D.pauseSeconds
                    } content: {
                        NavigationLink {
                            ActivityModeView()
                        } label: {
                            LabeledContent("Background activity", value: health.activityMode.shortTitle)
                        }
                    }
                } header: {
                    Text("Heart Minutes")
                }

                Section {
                    ResetRow(changed: health.zoneModel != D.zoneModel, info: String(localized: "2 zones: moderate from 50 % and vigorous from 70 % of max heart rate – the American Heart Association (AHA) recommendation. Moderate counts × 1 and vigorous × 2, so 150 min moderate or 75 min vigorous per week is enough.\n\n5 zones: the common zones used by e.g. Garmin and Polar (Z1 from 50 %, Z2 60 %, Z3 70 %, Z4 80 %, Z5 90 %). Z0 is heart rate below 50 %.\n\nLimits and factors can be changed under “Your zones”.")) {
                        health.zoneModel = D.zoneModel
                    } content: {
                        Picker("Number of zones", selection: $health.zoneModel) {
                            ForEach(ZoneModel.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text("Heart rate zones")
                } footer: {
                    if health.zoneModel == .two {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Follows the American Heart Association (AHA) recommendations: moderate 50–70 %, vigorous from 70 % of max heart rate.")
                            Link(destination: AHA.targetHeartRatesURL) {
                                Text("Source: American Heart Association – Target Heart Rates")
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .font(.footnote)
                        }
                    }
                }

                Section {
                    ResetRow(changed: health.maxHRSource != D.maxHRSource, info: String(localized: "Age: max heart rate = 220 − age.\nEnter: your own max heart rate, e.g. measured in a test.")) {
                        health.maxHRSource = D.maxHRSource
                    } content: {
                        Picker("Max heart rate from", selection: $health.maxHRSource) {
                            ForEach(MaxHRSource.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    switch health.maxHRSource {
                    case .age:
                        ResetRow(changed: health.age != health.defaultAge, info: String(localized: "Default: your age from your date of birth in Health.")) {
                            health.age = health.defaultAge
                        } content: {
                            Stepper("Age: \(health.age) years", value: $health.age, in: 10...100)
                        }
                        LabeledContent("Max heart rate (220 − age)", value: "\(Int(health.maxHR.rounded())) bpm")
                    case .manual:
                        ResetRow(changed: health.manualMaxHR != health.defaultMaxHR, info: String(localized: "The highest heart rate your heart can reach – e.g. measured in a test or the same as in another app. Default: 220 − your age.")) {
                            health.manualMaxHR = health.defaultMaxHR
                        } content: {
                            Stepper("Max heart rate: \(health.manualMaxHR) bpm", value: $health.manualMaxHR, in: 120...230)
                        }
                    }
                } header: {
                    Text("Max heart rate")
                }

                Section {
                    ForEach(health.zones.indices, id: \.self) { i in
                        zoneRow(i)
                    }
                } header: {
                    Text("Your zones")
                } footer: {
                    Text("The limits are a percentage of your max heart rate (\(Int(health.maxHR.rounded())) bpm). The factor is how much one minute in the zone counts; by default the lowest zone doesn’t count (× 0).")
                }

                Section {
                    ResetRow(changed: health.watchPeriod != D.watchPeriod, info: String(localized: "The period shown by the complications and the Apple Watch app. The goal is scaled to the period, e.g. about 21 min for Today.")) {
                        health.watchPeriod = D.watchPeriod
                    } content: {
                        // Short label (the section is called "Apple Watch") and a menu picker on the same line, so
                        // "Last 7 days" doesn't wrap the line.
                        LabeledContent("Period") {
                            Picker("Period on the watch", selection: $health.watchPeriod) {
                                ForEach(SummaryPeriod.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .fixedSize()
                        }
                        .lineLimit(1)
                    }
                } header: {
                    Text("Apple Watch")
                }

                Section {
                    NavigationLink {
                        AdvancedSettingsView()
                    } label: {
                        Label("Advanced", systemImage: "slider.horizontal.3")
                    }
                } footer: {
                    Text("Comparison, heart rate between measurements and gaps.")
                }

                Section {
                    Button("Reset all settings", role: .destructive) { confirmResetAll = true }
                } footer: {
                    Text("Tap ⓘ to see what a setting does. \(Image(systemName: "arrow.counterclockwise")) appears when a setting has been changed – tap it to reset the setting to its default.")
                }
            }
            .navigationTitle("Settings")
            // Alert in the middle of the screen (a confirmationDialog shows as a bubble at the top of the Form).
            .alert("Reset all settings?", isPresented: $confirmResetAll) {
                Button("Reset all", role: .destructive) { health.resetAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All settings will be reset to their defaults.")
            }
        }
    }

    /// One zone in "Your zones": name and bpm, limit in % (not for the lowest) and factor.
    @ViewBuilder private func zoneRow(_ i: Int) -> some View {
        let z = health.zones
        let model = health.zoneModel
        let changed = abs(z.percents[i] - model.defaultPercents[i]) > 0.001
            || abs(z.weights[i] - model.defaultWeights[i]) > 0.001
        ResetRow(changed: changed) {
            setZone(i, percent: model.defaultPercents[i], weight: model.defaultWeights[i])
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(z.color(i).opacity(0.5))
                        .frame(width: 14, height: 14)
                    Text(z.name(i)).bold()
                    Spacer()
                    Text(rangeText(i)).foregroundStyle(.secondary)
                }
                if i > 0 {
                    // The limit must lie between the neighbouring zones' limits.
                    let pct = Int((z.percents[i] * 100).rounded())
                    let lo = max(Int((z.percents[i - 1] * 100).rounded()) + 1, 1)
                    let hi = i + 1 < z.count ? Int((z.percents[i + 1] * 100).rounded()) - 1 : 100
                    let pMinus: (() -> Void)? = pct > lo ? { setZone(i, percent: Double(pct - 1) / 100) } : nil
                    let pPlus: (() -> Void)? = pct < hi ? { setZone(i, percent: Double(pct + 1) / 100) } : nil
                    miniStepper("From \(pct) %", minus: pMinus, plus: pPlus)
                }
                let w = z.weights[i]
                let wMinus: (() -> Void)? = w > 0 ? { setZone(i, weight: max(0, w - 0.5)) } : nil
                let wPlus: (() -> Void)? = w < 5 ? { setZone(i, weight: min(5, w + 0.5)) } : nil
                miniStepper("Counts × \(w.formatted(.number.precision(.fractionLength(0...1))))",
                            minus: wMinus, plus: wPlus)
            }
            .padding(.vertical, 8)
        }
    }

    /// The same Stepper as for age; a button is disabled when the limit is reached.
    private func miniStepper(_ label: LocalizedStringKey, minus: (() -> Void)?, plus: (() -> Void)?) -> some View {
        Stepper(label, onIncrement: plus, onDecrement: minus)
    }

    private func setZone(_ i: Int, percent: Double? = nil, weight: Double? = nil) {
        if let percent { var p = health.zonePercents; p[i] = percent; health.zonePercents = p }
        if let weight { var w = health.zoneWeights; w[i] = weight; health.zoneWeights = w }
    }

    /// E.g. "93–130 bpm", "below 93 bpm" or "from 130 bpm".
    private func rangeText(_ i: Int) -> String {
        let z = health.zones
        let r = z.bpmRange(i)
        if i == 0 { return String(localized: "below \(Int(r.upperBound.rounded())) bpm") }
        if i == z.count - 1 { return String(localized: "from \(Int(r.lowerBound.rounded())) bpm") }
        return "\(Int(r.lowerBound.rounded()))–\(Int(r.upperBound.rounded())) bpm"
    }
}

/// A setting with ↺ (only shown when the value differs from the default) and ⓘ (explanation) at the trailing edge.
private struct ResetRow<Content: View>: View {
    let changed: Bool
    var info: String? = nil
    let reset: () -> Void
    @ViewBuilder let content: Content
    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 10) {
            content
            // ↺ always keeps its place (invisible when the value is the default), so the controls and ⓘ line up in
            // every row and don't jump when ↺ appears.
            Button(action: reset) {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: 22)
            .opacity(changed ? 1 : 0)
            .disabled(!changed)
            .accessibilityHidden(!changed)
            .accessibilityLabel("Reset to default")
            if let info {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .frame(width: 22)
                .accessibilityLabel("Legend")
                .popover(isPresented: $showInfo) {
                    Text(info)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 290, alignment: .leading)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
    }
}

/// Advanced settings: fine-tuning of the calculation and the display.
struct AdvancedSettingsView: View {
    @Environment(HealthManager.self) private var health
    @FocusState private var editingGap: Bool

    private typealias D = HealthManager.Defaults

    var body: some View {
        @Bindable var health = health
        Form {
            Section {
                    ResetRow(changed: health.showComparison != D.showComparison, info: String(localized: "Shows your Exercise ring minutes (the green ring on Apple Watch) as a green line in the Heart Minutes chart so you can see the difference. The calculation always uses your heart rate zones.")) {
                        health.showComparison = D.showComparison
                    } content: {
                        Toggle("Compare with Exercise ring minutes", isOn: $health.showComparison)
                    }
            } header: {
                Text("Calculation")
            }

                Section {
                    ResetRow(changed: health.interpolation != D.interpolation, info: ActiveMinutes.Interpolation.allExplained) {
                        health.interpolation = D.interpolation
                    } content: {
                        Picker("Heart rate between measurements", selection: $health.interpolation) {
                            ForEach(ActiveMinutes.Interpolation.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Heart rate between measurements")
                } footer: {
                    Text("\(health.interpolation.title): \(health.interpolation.explanation)")
                }

                Section {
                    ResetRow(changed: health.maxGapSeconds != D.maxGapSeconds, info: String(localized: "If there is more time between two measurements outside a workout than this, the time in between doesn’t count – nothing was measured. From 1 to \(D.maxGapLimit) s. Default: \(D.maxGapSeconds) s (5 min).")) {
                        health.maxGapSeconds = D.maxGapSeconds
                    } content: {
                        // Type the number of seconds yourself (1–600).
                        LabeledContent("Outside workouts") {
                            HStack(spacing: 4) {
                                TextField("s", value: $health.maxGapSeconds, format: .number)
                                    .keyboardType(.numberPad)
                                    .focused($editingGap)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 60)
                                Text("s").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onChange(of: health.maxGapSeconds) { _, v in
                        let clamped = min(max(v, 1), D.maxGapLimit)
                        if clamped != v { health.maxGapSeconds = clamped }
                    }
                    ResetRow(changed: health.workoutGaps != D.workoutGaps, info: ActiveMinutes.WorkoutGaps.allExplained) {
                        health.workoutGaps = D.workoutGaps
                    } content: {
                        Picker("In workouts", selection: $health.workoutGaps) {
                            ForEach(ActiveMinutes.WorkoutGaps.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Gaps in measurements")
                } footer: {
                    Text("Outside workouts, gaps of up to \(Int(health.maxGap)) s count. During workouts \(health.workoutGaps.summary)")
                }
        }
        .navigationTitle("Advanced")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            // The number pad has no return key, so there is a "Done" button above it.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { editingGap = false }.bold()
            }
        }
    }
}

/// Choose when background heart rate counts – one list with an explanation below each choice.
struct ActivityModeView: View {
    @Environment(HealthManager.self) private var health
    @FocusState private var editingPause: Bool
    private typealias D = HealthManager.Defaults

    var body: some View {
        @Bindable var health = health
        Form {
            Section {
                ForEach(ActiveMinutes.ActivityMode.allCases) { mode in
                    Button {
                        health.activityMode = mode
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(mode.title).foregroundStyle(Color.primary)
                                Text(mode.explanation).font(.caption).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            if health.activityMode == mode {
                                Image(systemName: "checkmark").foregroundStyle(.tint).fontWeight(.semibold)
                            }
                        }
                    }
                }
            } footer: {
                Text("When your heart rate during the day – outside workouts – counts as Heart Minutes. Workouts always count.")
            }

            if health.activityMode == .withPauses || health.activityMode == .watchWithPauses {
                Section {
                    // Type the number of seconds yourself (1–600).
                    LabeledContent("Longest pause") {
                        HStack(spacing: 4) {
                            TextField("s", value: $health.pauseSeconds, format: .number)
                                .keyboardType(.numberPad)
                                .focused($editingPause)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 60)
                            Text("s").foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Joins two active stretches when the pause between them is at most this many seconds (1–\(D.pauseLimit)). Then, for example, gardening with short breaks counts as one continuous activity. The filled-in pauses are shown in light blue at the bottom of the heart rate chart.")
                }
            }
        }
        .navigationTitle("Background activity")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            // The number pad has no return key, so there is a "Done" button above it.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { editingPause = false }.bold()
            }
        }
    }
}
