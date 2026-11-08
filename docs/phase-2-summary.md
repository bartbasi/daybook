# Phase 2 summary

Repo: https://github.com/bartbasi/daybook (public).

## What was done

1. **Flutter project.**
   - Package `io.github.bartbasi.daybook` on Android and iOS, Flutter 3.47.7.
   - LICENSE is copied verbatim from WoodLogic.
   - NOTICE uses the WoodLogic wording with the name changed to Daybook. It adds a short section crediting the USDA and Open Food Facts data.
   - Every source file starts with the same two-line header as WoodLogic.
   - The app name is in one constant (`lib/app_info.dart`), and UI text is in one strings file (`lib/strings.dart`).
2. **Database schema.**
   - 25 tables in a drift database, schema version 1. They cover:
     - foods, nutrients, portions and recipes;
     - meal slots and their time rules, meals and meal entries;
     - saved meals and aliases, plus learned corrections;
     - weight;
     - exercises, routines, workouts and sets, and cardio;
     - profile, goals and settings.
   - Schema snapshots and migration tooling are in place, and CI blocks a schema change that has no new version.
   - The design is in [data-model.md](data-model.md).
3. **USDA shipping decision: bundle it.**
   - 7.1 MB on the download, 13,598 foods from SR Legacy, FNDDS and Foundation Foods.
   - No download and no extra network call, and it works offline at first launch.
   - The trade-off table is in data-model.md, "Food data shipping".
4. **USDA data loaded, and Open Food Facts barcode lookup wired.**
   - `tools/build_food_db.py` builds the asset from pinned USDA files.
   - The app installs it on first run.
   - Barcode lookup sends the agreed User-Agent and caches the product on the phone.
   - It does not show product photos.
5. **Export and import.**
   - Export writes one zip: `daybook.json` (everything), one CSV per table, and a README with the Open Food Facts license note.
   - Import checks the whole file, then replaces all data in one transaction. A bad file changes nothing.
   - 45 tests cover this, including a round trip of every table and 29 kinds of bad file.
6. **CI** (`.github/workflows/ci.yml`), on every push:
   - checks that generated code and the schema snapshot are up to date;
   - runs the analyzer and all tests;
   - builds an Android APK;
   - builds an unsigned iOS release on a macOS runner.

   The APK is saved as a build artifact for 14 days.

Tests: 67 Dart tests and 5 Python tests, all passing.

## Review

An Opus reviewer that did not write the code checked everything against BRIEF.md and CLAUDE.md. It found 13 issues, and all were fixed, each starting with a failing test. The important ones:

- An import with a wrong value type (for example text where a weight should be) could wipe the data and then crash the app. Now it is refused, and so is a file missing any table.
- Folate (DFE) was too low for enriched foods (enriched flour showed 160 µg instead of about 291). Now folate is "not listed" when USDA does not give the DFE value.
- A rebuilt food database would never have reached existing installs. The data version is now tied to the file contents.
- Deleted weigh-ins and cardio sessions are now marked deleted instead of removed, so a later Health Connect or Apple Health sync cannot bring them back. This was cheap to add before release and costly after.
- Release builds log only an error's type, never its message, because database errors can contain user data.

## How to check the gate

**Nutrition numbers.** Install the app and use the temporary "Data check" screen. It is a plain screen for this gate only; Phase 4 replaces it with the designed screens.

1. Get the APK:
   - from the latest CI run: https://github.com/bartbasi/daybook/actions, open the run, then the `daybook-android` artifact;
   - or plug in the phone and run `flutter run --release` in the project folder.
2. Type a food in the search box, for example `egg whole raw`, and tap a result.
3. The screen shows every tracked nutrient per 100 g. The drop-down switches to a household portion (for example "1 large (50 g)").
4. To check a packaged food, type a barcode in the top box and tap Look up. That is the only network call the app makes.

Compare against https://fdc.nal.usda.gov (search the same food; the FDC number is shown under the name) or the package label.

**Export and import round trip.** This is proven by the automated tests (`test/data/export_import_test.dart`), which CI runs on every push. There are no Export or Import buttons yet. Those belong to the About and settings screens in Phase 4, after Phase 3 designs them.

**CI.** Both jobs are green on the latest run: https://github.com/bartbasi/daybook/actions/runs/42511685464 (Test and Android build: passed; iOS build: passed).

## Decisions made (say if you want any changed)

- **Export is one zip holding both JSON and CSV.** The brief's "single file (JSON and CSV)" could also mean "pick JSON or CSV". Import reads the JSON.
- **Import replaces all data; it does not merge.** It is meant for restoring a backup or moving to a new phone.
- **FNDDS is included** (+2.4 MB). It has foods as eaten, which should help free-text matching. Without it the asset is 4.7 MB.
- **50 Foundation foods are left out** because USDA gives them no calorie value at all (several oils, butter, dry beans). SR Legacy still has those foods.
- **Fallbacks for missing values:**
  - Foundation foods often have no plain calorie value. The build uses USDA's Atwater energy instead: the "specific" factors when given, otherwise "general". 279 foods use this.
  - 8 foods with no total fat use the NLEA fat value.
  - The full list is in data-model.md.
- **App size.** One APK for all phone types is 61 MB. Google Play delivers a per-phone build, which is about 26 MB installed on a 64-bit phone, of which 7.1 MB is food data.

## Not done or not checked

- I could not run the app on a phone or emulator. No device was connected and no emulator image is installed. A widget test drives the real screen against the real bundled data (egg: 143 kcal and 12.56 g protein per 100 g, 71.5 kcal per large egg), but the first launch on a real phone is still for you to check.
- The iOS build is unsigned and only compiled in CI. Signing and TestFlight are Phase 6.
- The CI APK is signed with Flutter's debug key. It is fine for installing by hand, but not for the store.
- The wger exercise library and Compendium MET values are not loaded yet. The schema has places for them, and loading them belongs to Phase 4 steps 4 and 5.
- Old export files: only schema v1 exists, so nothing to migrate yet. A golden v1 file is in the tests, so a later schema change cannot silently break old backups.
- The Compendium permission email: still for you to send (draft in phase-1-summary.md).

## Gate

Phase 2 is done. Waiting for Bart to check nutrition numbers for foods he picks, and to confirm the round trip and both CI builds, before starting Phase 3.
