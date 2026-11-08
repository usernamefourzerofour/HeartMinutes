# Heart Minutes – huskeliste

## Skal gøres
- [ ] **Formel for maks-puls pr. år** i stedet for AHA's aldersgrupper (lige nu: AHA-tabellen,
      se `HeartZones.ahaTable`). Kandidater:
  - Tanaka m.fl. 2001: `208 − 0,7 × alder` (metaanalyse, 18.712 personer) – https://pubmed.ncbi.nlm.nih.gov/11153730/
  - Gellish m.fl. 2007: `207 − 0,7 × alder` (longitudinelt, 132 personer, 908 tests)
  - Nes m.fl. 2013 (HUNT, Norge): `211 − 0,64 × alder` (3.320 raske nordmænd)
  - Sammenligning: https://pmc.ncbi.nlm.nih.gov/articles/PMC7523886
  - Idé: formelvalg i Indstillinger med kildelink.

- [ ] **5 pulszoner som ekstra valg** (semi-avanceret). Standard forbliver Let/Moderat/Hård.
  - Indstillinger → Pulszoner: "Zonemodel: Moderat og hård (standard) / 5 zoner".
  - Grænser: % af maks-puls, standard 50 / 60 / 70 / 80 / 90 % (den udbredte model hos
    Garmin, Polar m.fl.). Find en troværdig kilde at linke til.
  - **Hver zone har sin egen faktor**, også "Under Z1". Standard: 0 / 1 / 1 / 2 / 2 / 2
    (giver samme resultat som moderat/hård). Trin 0,5 fra 0 til 3.
  - Vægtene for moderat/hård under Avanceret skjules i 5-zone-tilstand.
  - Pulsgraf: 5 farvebånd. Regnestykke: "Z2 14 min × 1 + Z3 5 min × 2 … = N min" (skjul zoner med 0 min).
  - Widgets og ur uændrede.

- [ ] **Zonegrænser i % af maks-puls i stedet for bpm** (både standard og 5 zoner).
  - Gem procenter; vis bpm ved siden af (udregnet).
  - "Manuelt" (bpm) erstattes af redigerbare procenter; maks-puls kan stadig sættes manuelt.
  - Migrering: omregn eksisterende manuelle bpm-grænser til % af nuværende maks-puls.

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
