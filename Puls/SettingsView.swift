import SwiftUI

/// Indstillinger: de vigtigste her, resten under "Avanceret".
/// En indstilling, der er ændret fra standard, får en ↺-knap, der sætter den tilbage.
struct SettingsView: View {
    @Environment(HealthManager.self) private var health
    @State private var confirmResetAll = false

    private typealias D = HealthManager.Defaults

    var body: some View {
        @Bindable var health = health
        NavigationStack {
            Form {
                Section {
                    ResetRow(changed: health.minutesSource != D.minutesSource, info: "Pulszoner: minutter i moderat og hård pulszone, ganget med vægtene (AHA) – beregnet af Heart Minutes ud fra din puls.\nTræningsring: træningsringsminutter – den grønne ring på Apple Watch – lagt sammen over den valgte periode. Apple bruger både puls og bevægelse.\n\nVælger du Træningsring, skjules de indstillinger, der kun gælder pulsberegningen.") {
                        health.minutesSource = D.minutesSource
                    } content: {
                        Picker("Beregn ud fra", selection: $health.minutesSource) {
                            ForEach(ActiveMinutes.Source.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    ResetRow(changed: health.weeklyGoal != D.weeklyGoal, info: "Dit mål pr. uge. AHA anbefaler mindst 150 min moderat eller 75 min hård aktivitet om ugen. Målet skaleres til den valgte periode, fx ca. 21 min for én dag.") {
                        health.weeklyGoal = D.weeklyGoal
                    } content: {
                        Stepper(value: $health.weeklyGoal, in: 10...1000, step: 10) {
                            Text("Mål: \(health.weeklyGoal) min pr. uge")
                        }
                    }
                    if health.minutesSource == .heartRate {
                        ResetRow(changed: health.activityMode != D.activityMode || health.pauseSeconds != D.pauseSeconds,
                                 info: "Hvornår din puls i løbet af dagen (uden for workouts) tæller med:\n\n" + ActiveMinutes.ActivityMode.allCases.map { "• \($0.title): \($0.explanation)" }.joined(separator: "\n") + "\n\nMålinger under workouts tæller altid.") {
                            health.activityMode = D.activityMode
                            health.pauseSeconds = D.pauseSeconds
                        } content: {
                            NavigationLink {
                                ActivityModeView()
                            } label: {
                                LabeledContent("Baggrundsaktivitet", value: health.activityMode.shortTitle)
                            }
                        }
                    }
                } header: {
                    Text("Heart Minutes")
                }

                // Pulszoner bruges kun, når minutterne regnes ud fra pulsen.
                if health.minutesSource == .heartRate {
                    Section {
                        ResetRow(changed: health.zoneModel != D.zoneModel, info: "2 zoner: moderat fra 50 % og hård fra 70 % af maks-puls – American Heart Association (AHA)'s anbefaling. Moderat tæller × 1 og hård × 2, så 150 min moderat eller 75 min hård om ugen er nok.\n\n5 zoner: de gængse zoner fra fx Garmin og Polar (Z1 fra 50 %, Z2 60 %, Z3 70 %, Z4 80 %, Z5 90 %). Z0 er pulsen under 50 %.\n\nGrænser og faktorer kan ændres under »Dine zoner«.") {
                            health.zoneModel = D.zoneModel
                        } content: {
                            Picker("Antal zoner", selection: $health.zoneModel) {
                                ForEach(ZoneModel.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                    } header: {
                        Text("Pulszoner")
                    } footer: {
                        if health.zoneModel == .two {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Følger anbefalingerne fra American Heart Association (AHA): moderat 50–70 %, hård fra 70 % af maks-puls.")
                                Link("Kilde: American Heart Association – Target Heart Rates",
                                     destination: AHA.targetHeartRatesURL)
                                    .font(.footnote)
                                    .multilineTextAlignment(.leading)
                            }
                        } else {
                            Text("De gængse 5 zoner (fx Garmin og Polar): Z1–Z5 fra 50, 60, 70, 80 og 90 % af maks-puls. Z0 er pulsen under 50 %.")
                        }
                    }

                    Section {
                        ResetRow(changed: health.maxHRSource != D.maxHRSource, info: "Alder: maks-puls = 220 − alder – den mest udbredte formel, som AHA's tabel også bygger på.\nIndtast: din egen maks-puls, fx målt ved en test.") {
                            health.maxHRSource = D.maxHRSource
                        } content: {
                            Picker("Maks-puls ud fra", selection: $health.maxHRSource) {
                                ForEach(MaxHRSource.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                        switch health.maxHRSource {
                        case .age:
                            ResetRow(changed: health.age != health.defaultAge, info: "Standard: alderen fra din fødselsdato i Sundhed.") {
                                health.age = health.defaultAge
                            } content: {
                                Stepper("Alder: \(health.age) år", value: $health.age, in: 10...100)
                            }
                            // ⓘ viser AHA's tabel; ingen ↺ (værdien følger alderen).
                            ResetRow(changed: false, info: ahaTableInfo) {} content: {
                                LabeledContent("Maks-puls", value: "\(Int(health.maxHR.rounded())) bpm")
                            }
                        case .manual:
                            ResetRow(changed: health.manualMaxHR != health.defaultMaxHR, info: "Den højeste puls, dit hjerte kan nå – fx målt ved en test eller den samme som i en anden app. Standard: 220 − din alder.") {
                                health.manualMaxHR = health.defaultMaxHR
                            } content: {
                                Stepper("Maks-puls: \(health.manualMaxHR) bpm", value: $health.manualMaxHR, in: 120...230)
                            }
                        }
                    } header: {
                        Text("Maks-puls")
                    }

                    Section {
                        ForEach(health.zones.indices, id: \.self) { i in
                            zoneRow(i)
                        }
                    } header: {
                        Text("Dine zoner")
                    } footer: {
                        Text("Grænserne er i procent af din maks-puls (\(Int(health.maxHR.rounded())) bpm). Faktoren er, hvor meget ét minut i zonen tæller; de nederste zoner tæller som udgangspunkt ikke (× 0).")
                    }
                }

                // Målinger bestemmer, hvad der tæller i pulsberegningen – ikke relevant ved Træningsring.
                if health.minutesSource == .heartRate {
                    Section {
                        ResetRow(changed: health.includeBackground != D.includeBackground, info: "Pulsmålinger taget i løbet af dagen uden for workouts – typisk af Apple Watch, men også fra andre enheder, der gemmer puls i Sundhed. Slå fra for kun at se og tælle workouts.") {
                            health.includeBackground = D.includeBackground
                        } content: {
                            Toggle(isOn: $health.includeBackground) {
                                Label("Baggrundsmålinger", systemImage: "applewatch")
                            }
                            .tint(HeartChart.backgroundColor)
                        }
                        ResetRow(changed: health.includeWorkouts != D.includeWorkouts, info: "Pulsmålinger taget under en registreret træning (workout).") {
                            health.includeWorkouts = D.includeWorkouts
                        } content: {
                            Toggle(isOn: $health.includeWorkouts) {
                                Label("Workouts", systemImage: "figure.run")
                            }
                            .tint(HeartChart.workoutColor)
                        }
                    } header: {
                        Text("Målinger")
                    } footer: {
                        Text("Hvilke pulsmålinger der tæller med i Heart Minutes og vises i pulsgrafen.")
                    }
                }

                Section {
                    ResetRow(changed: health.watchPeriod != D.watchPeriod, info: "Den periode, som komplikationerne og Apple Watch-appen viser. Målet skaleres til perioden, fx ca. 21 min for I dag.") {
                        health.watchPeriod = D.watchPeriod
                    } content: {
                        // Kort etiket (sektionen hedder "Apple Watch") og menu-vælger på samme linje,
                        // så "Seneste 7 dage" ikke får linjen til at bryde.
                        LabeledContent("Periode") {
                            Picker("Periode på uret", selection: $health.watchPeriod) {
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
                        Label("Avanceret", systemImage: "slider.horizontal.3")
                    }
                } footer: {
                    Text(health.minutesSource == .heartRate
                         ? "Sammenligning, vægte, puls mellem målinger og huller."
                         : "Sammenligning med pulszoner.")
                }


                Section {
                    Button("Nulstil alle indstillinger", role: .destructive) { confirmResetAll = true }
                } footer: {
                    Text("Tryk på ⓘ for at se, hvad en indstilling gør. \(Image(systemName: "arrow.counterclockwise")) vises, når en indstilling er ændret – tryk på den for at sætte indstillingen tilbage til standard.")
                }
            }
            .navigationTitle("Indstillinger")
            // Alert midt på skærmen (en confirmationDialog vises som en boble ved Form'en øverst).
            .alert("Nulstil alle indstillinger?", isPresented: $confirmResetAll) {
                Button("Nulstil alle", role: .destructive) { health.resetAll() }
                Button("Annuller", role: .cancel) {}
            } message: {
                Text("Alle indstillinger sættes tilbage til standard.")
            }
        }
    }


    /// AHA's tabel (Target Heart Rates Chart) som tekst til ⓘ ved AHA-aldersgruppe.
    private var ahaTableInfo: String {
        let rows = HeartZones.ahaTable.map { row in
            let m = Double(row.maxHR)
            return "\(row.age) år: maks \(row.maxHR) · moderat \(Int(m * 0.5))–\(Int(m * 0.7)) · hård \(Int(m * 0.7))–\(Int(m * 0.85)) bpm"
        }
        return "Maks-puls = 220 − alder (\(health.age) år → \(Int(health.maxHR.rounded())) bpm). AHA's tabel (Target Heart Rates) bygger på samme formel:\n\n"
            + rows.joined(separator: "\n")
    }

    /// Én zone i "Dine zoner": navn og bpm, grænse i % (ikke den nederste) og faktor.
    @ViewBuilder private func zoneRow(_ i: Int) -> some View {
        let z = health.zones
        let model = health.zoneModel
        let changed = abs(z.percents[i] - model.defaultPercents[i]) > 0.001
            || abs(z.weights[i] - model.defaultWeights[i]) > 0.001
        ResetRow(changed: changed) {
            setZone(i, percent: model.defaultPercents[i], weight: model.defaultWeights[i])
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(z.color(i).opacity(0.5))
                        .frame(width: 14, height: 14)
                    Text(z.name(i)).bold()
                    Spacer()
                    Text(rangeText(i)).foregroundStyle(.secondary)
                }
                if i > 0 {
                    // Grænsen skal ligge mellem nabozonernes grænser.
                    let lo = Int((z.percents[i - 1] * 100).rounded()) + 1
                    let hi = i + 1 < z.count ? Int((z.percents[i + 1] * 100).rounded()) - 1 : 100
                    Stepper("Fra \(Int((z.percents[i] * 100).rounded())) %",
                            value: Binding(get: { Int((z.percents[i] * 100).rounded()) },
                                           set: { setZone(i, percent: Double($0) / 100) }),
                            in: max(lo, 1)...max(hi, lo))
                }
                Stepper("Tæller × \(z.weights[i].formatted(.number.precision(.fractionLength(0...1))))",
                        value: Binding(get: { z.weights[i] }, set: { setZone(i, weight: $0) }),
                        in: 0...5, step: 0.5)
            }
        }
    }

    private func setZone(_ i: Int, percent: Double? = nil, weight: Double? = nil) {
        if let percent { var p = health.zonePercents; p[i] = percent; health.zonePercents = p }
        if let weight { var w = health.zoneWeights; w[i] = weight; health.zoneWeights = w }
    }

    /// Fx "93–130 bpm", "under 93 bpm" eller "fra 130 bpm".
    private func rangeText(_ i: Int) -> String {
        let z = health.zones
        let r = z.bpmRange(i)
        if i == 0 { return "under \(Int(r.upperBound.rounded())) bpm" }
        if i == z.count - 1 { return "fra \(Int(r.lowerBound.rounded())) bpm" }
        return "\(Int(r.lowerBound.rounded()))–\(Int(r.upperBound.rounded())) bpm"
    }
}

/// En indstilling med ↺ (vises kun, når værdien er ændret fra standard) og ⓘ (forklaring) yderst.
private struct ResetRow<Content: View>: View {
    let changed: Bool
    var info: String? = nil
    let reset: () -> Void
    @ViewBuilder let content: Content
    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 10) {
            content
            // ↺ har altid sin plads (usynlig, når værdien er standard), så kontrollerne og ⓘ
            // står på linje i alle rækker og ikke hopper, når ↺ dukker op.
            Button(action: reset) {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: 22)
            .opacity(changed ? 1 : 0)
            .disabled(!changed)
            .accessibilityHidden(!changed)
            .accessibilityLabel("Nulstil til standard")
            if let info {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .frame(width: 22)
                .accessibilityLabel("Forklaring")
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

/// Avancerede indstillinger: finjustering af beregningen og visningen.
struct AdvancedSettingsView: View {
    @Environment(HealthManager.self) private var health
    @FocusState private var editingGap: Bool

    private typealias D = HealthManager.Defaults

    var body: some View {
        @Bindable var health = health
        Form {
            Section {
                    ResetRow(changed: health.showComparison != D.showComparison, info: "Viser en stiplet linje i Heart Minutes-grafen med den anden beregning: træningsringsminutterne (den grønne træningsring på Apple Watch) eller dine pulszone-minutter – så du kan se forskellen.") {
                        health.showComparison = D.showComparison
                    } content: {
                        Toggle(health.minutesSource == .heartRate ? "Sammenlign med træningsringsminutter" : "Sammenlign med pulszoner",
                               isOn: $health.showComparison)
                    }
            } header: {
                Text("Beregning")
            }

                // Kun relevant, når minutterne regnes ud fra pulsen.
                if health.minutesSource == .heartRate {
                    Section {
                        ResetRow(changed: health.interpolation != D.interpolation, info: ActiveMinutes.Interpolation.allExplained) {
                            health.interpolation = D.interpolation
                        } content: {
                            Picker("Puls mellem målinger", selection: $health.interpolation) {
                                ForEach(ActiveMinutes.Interpolation.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.menu)
                        }
                    } header: {
                        Text("Puls mellem målinger")
                    } footer: {
                        Text("\(health.interpolation.title): \(health.interpolation.explanation)")
                    }

                    Section {
                        ResetRow(changed: health.maxGapSeconds != D.maxGapSeconds, info: "Er der længere tid mellem to målinger uden for en workout end dette, tæller tiden imellem ikke med – der er ikke målt. Fra 1 til \(D.maxGapLimit) s. Standard: \(D.maxGapSeconds) s (5 min).") {
                            health.maxGapSeconds = D.maxGapSeconds
                        } content: {
                            // Skriv selv antal sekunder (1–600).
                            LabeledContent("Uden for workouts") {
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
                            Picker("I workouts", selection: $health.workoutGaps) {
                                ForEach(ActiveMinutes.WorkoutGaps.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.menu)
                        }
                    } header: {
                        Text("Huller i målingerne")
                    } footer: {
                        Text("Uden for workouts tæller huller op til \(Int(health.maxGap)) s. Under workouts \(health.workoutGaps.summary)")
                    }
                }
        }
        .navigationTitle("Avanceret")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            // Taltastaturet har ingen retur-tast, så der er en "Færdig"-knap over det.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Færdig") { editingGap = false }.bold()
            }
        }
    }
}

/// Vælg, hvornår baggrundspuls tæller – én liste med forklaring under hvert valg.
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
                Text("Hvornår din puls i løbet af dagen – uden for workouts – tæller som Heart Minutes. Workouts tæller altid.")
            }

            if health.activityMode == .withPauses || health.activityMode == .watchWithPauses {
                Section {
                    // Skriv selv antal sekunder (1–600).
                    LabeledContent("Længste pause") {
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
                    Text("Kæder to aktive stykker sammen, når pausen imellem er højst så mange sekunder (1–\(D.pauseLimit)). Så tæller fx havearbejde med små pauser som én sammenhængende aktivitet. De udfyldte pauser vises lyseblå i bunden af pulsgrafen.")
                }
            }
        }
        .navigationTitle("Baggrundsaktivitet")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            // Taltastaturet har ingen retur-tast, så der er en "Færdig"-knap over det.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Færdig") { editingPause = false }.bold()
            }
        }
    }
}
