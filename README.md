# Monopoly Banker Pro

A Flutter-based **banker companion** for Monopoly game nights. It replaces the paper money and the mental math: the app acts as the bank, tracks every player's cash, deeds, houses and hotels, settles rent automatically, manages jail, mortgages, building and trades, and keeps a full transaction ledger for the whole game.

Built as a complete rewrite (v2.0) of the original web-based Monopoly Banker in Dart/Flutter for a native, polished mobile experience.

---

## Features

- **Game management** — create, resume, filter (active/finished), duplicate and delete games; every game is persisted locally as JSON.
- **New-game wizard** — pick rules, board edition, players, starting player and optional house rules before the first turn.
- **Banker console** (per game) with five tabs:
  - **Players** — cash, position, jail status, net worth, per-player actions (pay/collect, move, jail, bankrupt).
  - **Board** — visual board strip; tap a space to buy, auction, pay rent or view details.
  - **Deeds** — ownership overview, mortgage/unmortgage, build houses & hotels with even-building enforcement.
  - **Trade** — propose and execute multi-asset trades (cash + deeds + cards) between any players.
  - **Ledger** — full chronological transaction log of everything the bank did.
- **Turn engine** (`lib/game/engine.dart`, `controller.dart`) with real Monopoly rules:
  - Landing resolution: GO salary (except on the very first move), buy/auction for unowned deeds, **automatic rent payment** when landing on an opponent-owned space, tax, Chance/Community Chest, jail (go to / pay $50 / doubles / get-out-of-jail card).
  - Reminder prompts (SnackBar) when a turn ends on an unowned space so the bank never forgets to buy or auction.
  - Manual position setter with a space picker that lists space names with color-group dots.
- **3 board editions** (data-driven JSON in `assets/editions/`):
  - London (UK classic), US Atlantic City (classic), Paris (France).
  - Full 40-space definitions: prices, rent tables, mortgage values, building costs, color groups.
- **10 locales** with a custom lightweight i18n system (`lib/i18n/`): English, فارسی, Türkçe, العربية, Deutsch, Français, Italiano, 한국어, עברית, Español — 700+ keys each, with `{{placeholder}}` substitution and English fallback. **Full RTL support** for Persian, Arabic and Hebrew (audited layout, including bottom nav and option sheets).
- **7 themes** (`lib/theme/themes.dart`) — dark/light palettes with a felt-table aesthetic; theme + locale + prefs persisted via `shared_preferences`.
- **Settings as a full page** with bottom navigation, animated tab bar, Help and About pages, exit-confirm dialog, and a first-launch language picker that requires explicit confirmation.
- **Offline-first** — no account, no network, no ads. Games live on the device.

---

## Tech stack

| Layer | Choice |
|---|---|
| UI framework | Flutter 3 (Material 3), Dart SDK `^3.9.0` |
| State | Lightweight custom store (`lib/store/game_store.dart`, `prefs.dart`) — no BLoC/Riverpod; the `GameController` owns turn logic and notifies listeners |
| Persistence | `shared_preferences` (settings) + per-game JSON files in the app documents dir (`path_provider`) |
| i18n | Hand-rolled map-based system (`kLocaleStrings` in `lib/i18n/strings.g.dart`, generated from TS sources) with `flutter_localizations` delegates |
| Board data | JSON assets decoded at startup (`lib/data/editions.dart`) |
| External links | `url_launcher` (Telegram link on the About page) |
| Tests | `flutter_test` — game-logic tests, widget smoke test, RTL regression tests (`test/`) |
| Android host | Pure-Java `MainActivity` (`com.kazem.monopolybankerpro`), release-signed APK |

### Project structure

```
lib/
  main.dart                 # app entry, first-launch language gate
  data/editions.dart        # board-edition JSON decoding
  game/engine.dart          # pure turn/landing rule resolution
  game/controller.dart      # turn orchestration, rent auto-pay, logging
  models/game.dart          # Game, Player, Space, Deed state models
  store/game_store.dart     # JSON persistence of games
  store/prefs.dart          # locale/theme/settings via shared_preferences
  theme/themes.dart         # 7 AppTheme palettes
  i18n/l10n.dart            # locale metadata, tr() with fallback
  i18n/strings.g.dart       # generated 700+ key dictionaries (do not edit)
  screens/                  # language_picker, games_list, new_game_wizard,
                            # shell (bottom nav), settings_page, help/about,
                            # game/ (game_screen + 5 banker tabs)
assets/editions/            # london.json, us_classic.json, france.json
android/                    # host app (applicationId com.kazem.monopolybankerpro)
test/                       # app_test, game_logic_test, rtl_test
```

---

## Getting started

### Prerequisites

- Flutter SDK 3.35+ (Dart `^3.9.0`)
- Android SDK with `platforms;android-35` and `build-tools`
- A JDK 17+ for the Gradle build

### Run (debug)

```bash
flutter pub get
flutter run
```

### Build a release APK

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

The project uses a **pure-Java `MainActivity`** (`android/app/src/main/java/com/kazem/monopolybankerpro/MainActivity.java`) — no Kotlin plugin required, which keeps the Gradle build lean. Sign the APK with your own keystore for distribution (`android/key.properties` + `signingConfigs` in `app/build.gradle.kts`).

> **Note:** launcher icons (`android/app/src/main/res/mipmap-*/ic_launcher.png`) and `android/gradle/wrapper/gradle-wrapper.jar` are binary artifacts and are intentionally not committed here. Regenerate icons with `flutter_launcher_icons`, or copy them from a previous build; the Gradle wrapper jar is fetched automatically on first `./gradlew` run if missing.

---

## Board editions — data format

Each edition is a JSON file under `assets/editions/` with 40 ordered spaces:

```json
{
  "id": "london",
  "name": "London",
  "currency": "£",
  "spaces": [
    { "index": 0, "type": "go", "name": "GO" },
    { "index": 1, "type": "property", "name": "Old Kent Road",
      "group": "brown", "price": 60, "mortgage": 30, "houseCost": 50,
      "rent": [2, 10, 30, 90, 160, 250] }
  ]
}
```

Space `type` values: `go`, `property`, `railroad`, `utility`, `tax`, `chance`, `community`, `jail`, `gotojail`, `parking`, `free`. To add an edition, drop a new JSON file in the folder, register it in `lib/data/editions.dart`, and add its display name to the i18n dictionaries.

---

## Internationalization

- Locales live in `lib/i18n/l10n.dart` (`kLocales`); RTL flags drive `Directionality` across the app.
- Strings live in `lib/i18n/strings.g.dart` — **generated** from the original TypeScript sources (`pro-workspace/src/i18n/*.ts`) by `/tmp/i18n_convert.py`, then split into per-locale files (`lib/i18n/strings_<locale>.dart`) with `strings.g.dart` as the aggregator. Edit the TS sources and re-run the generator; never hand-edit the generated files.
- `tr(locale, key, params)` falls back to English, then to the key itself; `{{name}}` placeholders are substituted at call sites.
- The in-app credit line uses a per-locale transliteration of the author's name (en/de/fr/it/es `Kazem`, fa/ar `کاظم`, tr `Kazım`, ko `카젬`, he `קאזם`).

---

## Tests

```bash
flutter test
```

- `test/game_logic_test.dart` — engine unit tests (landing resolution, rent math, jail transitions).
- `test/app_test.dart` — widget smoke test of the app shell.
- `test/rtl_test.dart` — regression tests for RTL layout in fa/ar/he.

---

## Versioning

`pubspec.yaml` → `version: 1.0.0+4` (version name + Android `versionCode`). Bump both together for store/sideload updates.

---

## Acknowledgements

Developed by **Kazem** — [t.me/Kaz33mm](https://t.me/Kaz33mm) — with AI assistance (Muse by Meta).

## License

MIT License — see [LICENSE](LICENSE). Copyright (c) 2026 kazemjf.
