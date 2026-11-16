# Heart Minutes – huskeliste

## Skal gøres
- [x] **Maks-puls = 220 − alder** pr. år (mest udbredt; AHA's tabel bygger på den). Senere evt. Tanaka
      (`208 − 0,7 × alder`) som valg under Avanceret.

- [x] **2 eller 5 zoner** (build 50): 2 zoner (AHA) er standard, 5 zoner (Z0 under 50 %, Z1–Z5 fra 50/60/70/80/90 %). Grænser i % og
      faktor pr. zone redigeres under "Dine zoner"; nederste zone × 0 som udgangspunkt.
      Maks-puls ud fra alder eller indtastet. "Manuelt" (bpm) og vægte under Avanceret er fjernet.

- [x] ~~**Aktive minutter baseret på træningsringsminutter**~~ – fjernet igen i build 63; Heart Minutes
      bruger altid pulszonerne. Træningsringen kan stadig vises som sammenligning under Avanceret.

- [ ] **Mål for minutter i en bestemt zone** (fx "60 min i Z2 pr. uge" til grundtræning).
  - Kan delvist laves i dag med faktorerne: sæt den ønskede zone til × 1 og resten til × 0.
    Men så bliver det *hele* Heart Minutes-tallet, og man mister det almindelige mål.
  - Idé: et ekstra, valgfrit zonemål ved siden af Heart Minutes (zone + minutter pr. uge),
    vist som en ekstra linje/ring i appen og evt. som eget valg i widget/komplikation.
  - Hænger sammen med punktet nedenfor (separate mål for moderat/hård).

- [ ] **Separate mål for moderat og hård aktivitet** (kun standardmodellen, ikke 5 zoner) (fx AHA: 150 min moderat *eller* 75 min hård pr. uge).
      Idéer:
  - To mål i Indstillinger (moderat og hård) i stedet for/ud over ét samlet mål med vægte.
  - **To ringe** i komplikation/widgets (fx yderring = moderat, inderring = hård, som Aktivitet-ringene).
  - **Minutgrafen splittet i to**: fx to kurver/flader (moderat og hård) hver med sin egen mållinje,
    eller to små grafer under hinanden. Skal afklares, hvordan det bliver tydeligst.

- [x] **Apple Watch-komplikation** (build 18): ur-app + WidgetKit-komplikation (rund, hjørne, rektangulær,
      linje). Uret regner selv ugens minutter fra Sundhed hver ~30 min; indstillinger synkroniseres fra iPhone.
      Mangler måske: test på rigtigt ur, evt. valg af procent/minutter i én komplikation.

## App Store (1.0)
- [x] Privatlivs-manifest (PrivacyInfo.xcprivacy)
- [x] Privatlivspolitik og supportside skrevet (`docs/privacy.md`, `docs/index.md`)
- [x] Repo offentligt + GitHub Pages (`/docs`), så privatlivs- og support-URL virker
- [x] Tekster på engelsk (`docs/app-store.md`): navn, undertitel, beskrivelse, nøgleord, review-noter
- [x] Tekster oversat til appens øvrige 37 sprog (`Localization/app-store.json`)
- [x] Skærmbilleder: iPhone 6,9" og Apple Watch (`tools/screenshots/`)
- [x] App Store Connect: kategori, pris (gratis), alle lande, aldersgrænse, App Privacy, DSA (ikke-erhvervsdrivende)
- [x] Ikke-medicinsk forbehold i beskrivelsen
- [x] Test på rigtigt ur og telefon (Erik)
- [x] **Udgivet 16. nov. 2026** – build 72 godkendt efter én runde Guideline 2.1 (skærmoptagelse + noter om
      formål, brug, ingen eksterne tjenester, ingen regionale forskelle). App Store: https://apps.apple.com/app/id6831784976

## Næste version (1.0.1 / 1.1)
- [ ] Tilføj watch-billede 2 (kun ét kom med; Apple-kategorien er `APP_WATCH_ULTRA` for 422 × 514)
- [ ] Review-noter: "Settings tab" i stedet for "Settings (gear icon)"
- [ ] Hver ny version kræver "What's New"-tekst på alle sprog

## Idéer til senere
- Hurtigere opdatering af komplikationer (HKObserverQuery / skub fra telefonen)
- "Uge"-visning: minutter i moderat/hård mod AHA's 150/75 min pr. uge
  (https://www.heart.org/en/healthy-living/exercise-and-physical-activity/fitness-basics/aha-recs-for-physical-activity-in-adults)
- Debug-knap der lægger testdata i HealthKit på simulatoren (kræver skriveadgang)
- Navn på træningstype (workoutActivityType → dansk tekst)

## Kilder
- Zoner og maks-puls: AHA Target Heart Rates –
  https://www.heart.org/en/healthy-living/exercise-and-physical-activity/fitness-basics/target-heart-rates
