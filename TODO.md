# Heart Minutes – huskeliste

## Skal gøres
- [x] **Maks-puls = 220 − alder** pr. år (mest udbredt; AHA's tabel bygger på den). Senere evt. Tanaka
      (`208 − 0,7 × alder`) som valg under Avanceret.

- [x] **2 eller 5 zoner** (build 50): 2 zoner (AHA) er standard, 5 zoner 60/70/80/90 %. Grænser i % og
      faktor pr. zone redigeres under "Dine zoner"; nederste zone × 0 som udgangspunkt.
      Maks-puls ud fra alder eller indtastet. "Manuelt" (bpm) og vægte under Avanceret er fjernet.

- [x] **Aktive minutter baseret på træningsringsminutter** (`HKQuantityType(.appleExerciseTime)`,
      den grønne træningsring): "Beregn ud fra: Pulszoner / Træningsring" i Indstillinger.

- [ ] **Separate mål for moderat og hård aktivitet** (kun standardmodellen, ikke 5 zoner) (fx AHA: 150 min moderat *eller* 75 min hård pr. uge).
      Idéer:
  - To mål i Indstillinger (moderat og hård) i stedet for/ud over ét samlet mål med vægte.
  - **To ringe** i komplikation/widgets (fx yderring = moderat, inderring = hård, som Aktivitet-ringene).
  - **Minutgrafen splittet i to**: fx to kurver/flader (moderat og hård) hver med sin egen mållinje,
    eller to små grafer under hinanden. Skal afklares, hvordan det bliver tydeligst.
  - Overvej hvordan det spiller sammen med "Træningsring" som kilde (den har kun ét tal).

- [x] **Apple Watch-komplikation** (build 18): ur-app + WidgetKit-komplikation (rund, hjørne, rektangulær,
      linje). Uret regner selv ugens minutter fra Sundhed hver ~30 min; indstillinger synkroniseres fra iPhone.
      Mangler måske: test på rigtigt ur, evt. valg af procent/minutter i én komplikation.

## Idéer til senere
- "Uge"-visning: minutter i moderat/hård mod AHA's 150/75 min pr. uge
  (https://www.heart.org/en/healthy-living/exercise-and-physical-activity/fitness-basics/aha-recs-for-physical-activity-in-adults)
- Debug-knap der lægger testdata i HealthKit på simulatoren (kræver skriveadgang)
- Navn på træningstype (workoutActivityType → dansk tekst)

## Kilder
- Zoner og maks-puls: AHA Target Heart Rates –
  https://www.heart.org/en/healthy-living/exercise-and-physical-activity/fitness-basics/target-heart-rates
