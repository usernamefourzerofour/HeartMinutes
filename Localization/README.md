# Translations

English is the source language. All UI texts live in String Catalogs:

- `Shared/Localizable.xcstrings` – app, widgets, watch app and complications
- `HeartMinutes/InfoPlist.xcstrings`, `HeartMinutesWatch/InfoPlist.xcstrings` – Health permission texts

`translations.json` holds every English text (with `{0}`, `{1}` placeholders in English order) and its translations in
37 languages. Count-dependent texts use plural dicts (`one`, `few`, `many`, `other`, …). `build_catalog.py` turns the
keys Xcode extracts into a complete `Localizable.xcstrings`:

```sh
python3 Localization/build_catalog.py keys.json Localization/translations.json Shared/Localizable.xcstrings
```

Languages: Arabic, Bulgarian, Catalan, Chinese (Simplified and Traditional), Croatian, Czech, Danish, Dutch, English,
Finnish, French, German, Greek, Hebrew, Hindi, Hungarian, Indonesian, Italian, Japanese, Korean, Lithuanian, Malay,
Norwegian, Polish, Portuguese (Brazil and Portugal), Romanian, Russian, Slovak, Slovenian, Spanish (Spain and Latin
America), Swedish, Thai, Turkish, Ukrainian and Vietnamese.

The translations were made with AI help (Claude). Corrections from native speakers are very welcome as pull requests.
