# Translations

The app's source language is Danish. All UI texts live in String Catalogs:

- `Shared/Localizable.xcstrings` – app, widgets, watch app and complications
- `Puls/InfoPlist.xcstrings`, `PulsWatch/InfoPlist.xcstrings` – Health permission texts

`translations.json` holds every Danish text (with `{0}`, `{1}` placeholders) and its translations.
`build_catalog.py` turns the keys Xcode extracts into a complete `Localizable.xcstrings`:

```sh
python3 Localization/build_catalog.py keys.json Localization/translations.json Shared/Localizable.xcstrings
```

Languages: Danish, English, German, Swedish, Norwegian, Finnish, Dutch, French, Spanish, Italian,
Portuguese (Brazil), Japanese and Chinese (Simplified). Corrections are welcome as pull requests.
