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
                        ResetRow(changed: health.zoneMode != D.zoneMode, info: "Alder: maks-puls slås op i AHA's tabel for din alder.\nMaks-puls: du angiver selv din maks-puls.\nManuelt: du angiver selv grænserne i bpm.\n\nMed alder og maks-puls starter moderat zone ved 50 % og hård ved 70 % af maks-puls (AHA).") {
                            health.zoneMode = D.zoneMode
                        } content: {
                            Picker("Grænser baseret på", selection: $health.zoneMode) {
                                ForEach(ZoneMode.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                    } header: {
                        Text("Pulszoner")
                    } footer: {
                        // Kilden står i forklaringen som et lille link i stedet for sin egen sektion.
                        VStack(alignment: .leading, spacing: 4) {
                            Text(health.zoneMode == .manual
                                 ? "Angiv selv, ved hvilken puls hver zone starter."
                                 : "Moderat (moderate-intensity) ≈ 50–70 %, hård (vigorous) fra 70 % af maks-puls (AHA).")
                            // Kun når grænserne kommer fra AHA (ikke ved manuelle grænser).
                            if health.zoneMode != .manual {
                                Link("Kilde: American Heart Association – Target Heart Rates",
                                     destination: AHA.targetHeartRatesURL)
                                    .font(.footnote)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }

                    switch health.zoneMode {
                    case .age:
                        Section("Alder") {
                            ResetRow(changed: health.age != health.defaultAge, info: "Bruges til at slå din maks-puls op i AHA's tabel. Standard: alderen fra din fødselsdato i Sundhed.") {
                                health.age = health.defaultAge
                            } content: {
                                Stepper("Alder: \(health.age) år", value: $health.age, in: 10...100)
                            }
                            LabeledContent("AHA-aldersgruppe", value: "\(HeartZones.ahaCategory(for: health.age).age) år")
                            LabeledContent("Maks-puls", value: "\(Int(HeartZones.maxHR(age: health.age))) bpm")
                        }
                    case .maxHR:
                        Section {
                            ResetRow(changed: health.manualMaxHR != health.defaultMaxHR, info: "Den højeste puls, dit hjerte kan nå – fx målt ved en test eller den samme som i en anden app. Moderat starter ved 50 % og hård ved 70 % af den. Standard: AHA-tabellen for din alder.") {
                                health.manualMaxHR = health.defaultMaxHR
                            } content: {
                                Stepper("Maks-puls: \(health.manualMaxHR) bpm", value: $health.manualMaxHR, in: 120...230)
                            }
                            LabeledContent("Moderat fra", value: "\(Int((Double(health.manualMaxHR) * 0.5).rounded())) bpm")
                            LabeledContent("Hård fra", value: "\(Int((Double(health.manualMaxHR) * 0.7).rounded())) bpm")
                        } header: {
                            Text("Maks-puls")
                        } footer: {
                            Text("Brug din målte maks-puls eller den samme som i en anden app. Zonerne er AHA's 50 % og 70 % af den. Standard: AHA-tabellen for din alder.")
                        }
                    case .manual:
                        Section {
                            ResetRow(changed: health.manualModerate != health.defaultManualModerate, info: "Pulsen (bpm), hvor moderat zone starter. Under den tæller tiden ikke.") {
                                health.manualModerate = health.defaultManualModerate
                            } content: {
                                Stepper("Moderat starter: \(health.manualModerate)",
                                        value: $health.manualModerate, in: 40...(health.manualVigorous - 1))
                            }
                            ResetRow(changed: health.manualVigorous != health.defaultManualVigorous, info: "Pulsen (bpm), hvor hård zone starter. Hård zone har intet loft.") {
                                health.manualVigorous = health.defaultManualVigorous
                            } content: {
                                Stepper("Hård starter: \(health.manualVigorous)",
                                        value: $health.manualVigorous,
                                        in: (health.manualModerate + 1)...230)
                            }
                        } header: {
                            Text("Grænser (bpm)")
                        } footer: {
                            Text("Standard: AHA's grænser for din alder.")
                        }
                    }

                    Section {
                        ForEach(ZoneKind.shown) { kind in
                            LabeledContent {
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(rangeText(kind))
                                    Text(percentText(kind)).font(.caption).foregroundStyle(.secondary)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(kind.color.opacity(0.5))
                                        .frame(width: 14, height: 14)
                                    Text(kind.name)
                                }
                            }
                        }
                    } header: {
                        Text("Dine zoner")
                    } footer: {
                        Text("Procent af maks-puls \(Int(percentBaseMaxHR.rounded())) bpm" +
                             (health.zoneMode == .manual ? " (din maks-puls fra »Maks-puls«)." : "."))
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


    private func rangeText(_ kind: ZoneKind) -> String {
        let r = health.zones.bpmRange(kind)
        let lo = Int(r.lowerBound.rounded())
        switch kind {
        case .light: return "under \(Int(r.upperBound.rounded())) bpm"
        case .moderate: return "\(lo)–\(Int(r.upperBound.rounded())) bpm"
        case .vigorous: return "fra \(lo) bpm"   // intet loft
        }
    }

    /// Maks-pulsen procenterne regnes af – den, der gælder for de valgte indstillinger:
    /// Alder → AHA for din alder, Maks-puls → din maks-puls, Manuelt → din gemte maks-puls
    /// (standard: AHA for din alder), da manuelle grænser ikke selv har en maks-puls.
    private var percentBaseMaxHR: Double {
        switch health.zoneMode {
        case .age: HeartZones.maxHR(age: health.age)
        case .maxHR, .manual: Double(health.manualMaxHR)
        }
    }

    private func percentText(_ kind: ZoneKind) -> String {
        let r = health.zones.bpmRange(kind)
        let pct = { (bpm: Double) in Int((bpm / percentBaseMaxHR * 100).rounded()) }
        switch kind {
        case .light: return "under \(pct(r.upperBound)) %"
        case .moderate: return "\(pct(r.lowerBound))–\(pct(r.upperBound)) %"
        case .vigorous: return "fra \(pct(r.lowerBound)) %"
        }
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
                    if health.minutesSource == .heartRate {
                        ResetRow(changed: abs(health.moderateWeight - D.moderateWeight) > 0.001, info: "Hvor meget ét minut i moderat zone tæller. AHA: 1×.") {
                            health.moderateWeight = D.moderateWeight
                        } content: {
                            Stepper(value: $health.moderateWeight, in: 0...5, step: 0.1) {
                                Text("Moderat tæller: \(health.moderateWeight, format: .number.precision(.fractionLength(0...1)))×")
                            }
                        }
                        ResetRow(changed: abs(health.vigorousWeight - D.vigorousWeight) > 0.001, info: "Hvor meget ét minut i hård zone tæller. AHA: 2×, så 75 min hård svarer til 150 min moderat.") {
                            health.vigorousWeight = D.vigorousWeight
                        } content: {
                            Stepper(value: $health.vigorousWeight, in: 0...5, step: 0.1) {
                                Text("Hård tæller: \(health.vigorousWeight, format: .number.precision(.fractionLength(0...1)))×")
                            }
                        }
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
