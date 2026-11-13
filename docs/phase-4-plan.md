# Phase 4 build plan

Lead/Architect plan for Phase 4: build version 1. It turns the approved Phase 3 design into small tasks for the Sonnet implementation agents. An Opus reviewer checks each task before it is merged.

Read with: BRIEF.md, CLAUDE.md, PHASES.md, docs/phase-3-summary.md, docs/parser-grammar.md, docs/design/ (open `index.html`), docs/data-model.md.

Open questions for Bart are in [section 9](#9-open-questions-for-bart). Question 1 (the schema) has to be answered before task 0.1 starts. Question 2 (installing on the iPhone) has to be answered before the end of step 8.

## Contents

1. [How to run this plan](#1-how-to-run-this-plan)
2. [Architecture](#2-architecture)
3. [Step 0: changes to Phase 2 work](#3-step-0-changes-to-phase-2-work)
4. [Steps 1 to 8](#4-steps-1-to-8)
5. [Dependencies](#5-dependencies)
6. [Reference data still to load](#6-reference-data-still-to-load)
7. [Testing and the speed targets](#7-testing-and-the-speed-targets)
8. [Risks](#8-risks)
9. [Open questions for Bart](#9-open-questions-for-bart)
10. [Task count](#10-task-count)

## 1. How to run this plan

- Steps run in order: 0, then 1 to 8 as PHASES.md lists them. A step is done when every task in it is merged and CI is green on main. Then the next step starts.
- Inside a step, tasks run in the order listed. A task marked "parallel with" can run at the same time as the task it names, because they share no files.
- Only one UI task runs at a time. UI tasks all add text to `lib/strings.dart`, so two at once would touch the same file. Data and Test tasks never edit `strings.dart`.
- Each task gets: this section, section 2, its own row, and the files it lists. The agent writes only the files its task lists. If it needs another file changed, it stops and says so.
- The reviewer checks each task against BRIEF.md, CLAUDE.md, this plan and the frames or grammar sections the task names.

### Rules for every task

| Rule | Detail |
|---|---|
| Header | Every new source file starts with the same two-line header as the existing files. |
| Text | Every word a user sees is in `lib/strings.dart` (class `S`). The app name is only `appName` in `lib/app_info.dart`. Plain words; no em dashes or double hyphens in UI copy, docs or commit messages. |
| Logs | No `print`, `debugPrint` or `log` of anything that could hold user data. Errors go through `lib/error_log.dart`. |
| Network | No network code except `lib/data/off_client.dart` (barcode lookups). Health sync talks to the phone's health store, not the network. |
| Packages | Only the packages in [section 5](#5-dependencies), added in the task that names them, with a row in `docs/dependencies.md`. |
| Tests | Every task lists the tests that prove it done. `flutter analyze` and `flutter test` pass before review. A bug fix starts with a failing test. |
| Saving | Every write is confirmed on screen from the row read back, not from what was typed. Deletes offer Undo; the only "are you sure" is Import. |
| Layout | Tap targets 48 dp or more. States shown by words and shapes, never color alone. Text in sp, rows grow, nothing cut off. One column, at most 600 dp wide, centered when wider. Works at 344 dp. |
| Scope | Build what the frames and notes show. Nothing more. If a frame and the grammar disagree, the grammar wins for parsing and the frame wins for layout; report the disagreement. |

## 2. Architecture

Kept as plain as the brief allows. No state management package, no router package, no dependency injection package, no chart package.

### 2.1 Folder layout

```
lib/
  main.dart              starts error handlers, opens the database, runs DaybookApp
  app.dart               DaybookApp (MaterialApp) and HomeShell (bottom bar, five tabs)
  app_scope.dart         AppScope: one InheritedWidget holding the shared objects
  app_info.dart          app name, version, links (exists)
  strings.dart           every user-facing word (exists)
  error_log.dart         (exists)
  clock.dart             Now and Clock (see 2.4)
  util/
    units.dart           kg/lb, cm/in, m/mi/km, parsing and one-decimal display
    dates.dart           'YYYY-MM-DD' helpers: add days, Monday week start, labels
  data/                  database code; no Flutter widgets here
    database.dart        schema (exists)
    export_import.dart   (exists)
    food_reference.dart  USDA reference database (exists)
    nutrients.dart       tracked nutrients (exists), plus Daily Values in step 3
    off_client.dart      Open Food Facts lookup (exists)
    weight_data.dart     queries and writes for one feature each ...
    food_data.dart
    goal_data.dart
    exercise_library.dart
    workout_data.dart
    met_table.dart
    cardio_data.dart
    summary_data.dart
    settings_data.dart
  parser/                the meal text parser (pure Dart, no Flutter imports)
  math/                  pure functions: weight trend, calorie budget, training, cardio estimate
  platform/              thin wrappers around plugins: weight widget, rest alert, health sync, barcode
  screens/
    home/  food/  weight/  workouts/  cardio/  summary/  goals/  saved_meals/  my_foods/  more/
test/                    mirrors lib/ (test/data, test/parser, test/math, test/platform, test/screens)
  speed/                 tap-count tests for the six speed targets
  guards_test.dart       checks the promises in code (task 0.3)
integration_test/        runs on the Android emulator and iOS simulator in CI (task 0.3)
  flows/                 the speed-target flows, shared with test/speed/
tools/                   build scripts for reference data (Python standard library only)
assets/food/  assets/exercises/  assets/met/
```

### 2.2 How screens get data

- **Reads:** drift `watch()` queries feed `StreamBuilder`s. When anything writes, every screen showing that table updates by itself. Home, the Weight tab and Summary all work this way.
- **Writes:** plain `async` functions. Each returns the row read back after the write, and the screen builds its "Saved" message from that row.
- **Where queries live:** one file per feature in `lib/data/`, written as Dart extension methods on `AppDatabase` (for example `extension WeightData on AppDatabase`). No DAO classes, no repositories, no code generation beyond drift's own.
- **Screen state:** `StatefulWidget` and `setState`. The food entry screen holds its text, its added lines and its sticky corrections in its own `State`.
- **Shared objects:** `AppScope` is one small `InheritedWidget` (about 20 lines) that holds the `AppDatabase`, the `Clock`, the parser worker and the path of the USDA database. Screens read it with `AppScope.of(context)`.
- **Why no package:** drift already gives live data, and the app has no shared mutable state beyond the database. A state package (provider, riverpod, bloc) would add a dependency and a pattern for agents to learn, and solve nothing the database stream does not. A single `InheritedWidget` is the lightest thing that saves passing the database through every constructor.
- **Plugins in tests:** plugin wrappers in `lib/platform/` are plain functions and classes, not interfaces. Tests replace the plugin's method channel with `TestDefaultBinaryMessenger.setMockMethodCallHandler`. No fake classes in `lib/`.

### 2.3 Navigation

- `HomeShell` is a `Scaffold` with a Material 3 `NavigationBar`: Today, Summary, Workouts, Weight, More (icon and word each). The tab bodies sit in an `IndexedStack`, so each tab keeps its scroll position.
- Full screens (Food entry, Cardio, Goals, Settings, About, editors) are pushed on the root `Navigator` with `MaterialPageRoute`. They cover the tab bar, as drawn.
- The weight entry and the correction sheet are `showModalBottomSheet`.
- The home-screen widget opens the app with the link `daybook://weight`. `HomeShell` checks for it at start and when the app resumes, and opens the weight sheet over Home.
- Tabs and buttons that belong to later steps are shown but disabled until their step (for example the Cardio button until step 5). Nothing says "coming soon".

### 2.4 Clock, dates and time zones

All "now" comes from one injected clock, so tests can set any instant and any time zone offset.

```dart
class Now {
  final int utcMs;          // milliseconds since the epoch
  final int offsetMinutes;  // local offset at that instant
  String get localDate;     // 'YYYY-MM-DD' in that offset
  int get minuteOfDay;      // 0 to 1439 in that offset (for the default meal)
}
typedef Clock = Now Function();
Now systemNow();            // DateTime.now() and its timeZoneOffset
```

- Matches the stored columns exactly: `*_at_ms`, `tz_offset_minutes`, `local_date`.
- Date maths works on `local_date` strings and on wall-clock `DateTime`s built with `isUtc: true`, so daylight saving time never shifts a day. Helpers are in `lib/util/dates.dart`.
- A record's `local_date` is set once when it is made (or when the user changes its date) and never recomputed (data-model.md). "Today" is `clock().localDate`.
- Tests pass a `Clock` that returns any `Now`, including offsets from minus 12 to plus 14 hours and a change of offset between two calls.

### 2.5 Units, nutrient maths and other calculations

| What | Where | Notes |
|---|---|---|
| Unit conversion and display | `lib/util/units.dart` | Stored metric (data-model.md). 1 lb = 0.45359237 kg, 1 in = 2.54 cm, 1 mi = 1609.344 m. Display follows the `units` setting ('imperial' default, 'metric'). Weight shown with one decimal. |
| Units setting | `lib/data/settings_data.dart` | `watchUnits()` stream, read by every screen that shows a number with a unit. |
| Portion and gram maths, nutrient scaling for a line | `lib/parser/` | Grammar sections 4.4 to 4.7. |
| Weight trend | `lib/math/weight_trend.dart` | Daily average, then 10% of the way toward each day's average. |
| Mifflin-St Jeor, activity, rate, add-back, macros, low-intake warning | `lib/math/calorie_budget.dart` | Pure functions. |
| Epley, records, weekly volume | `lib/math/training.dart` | Pure functions. |
| MET band choice and cardio estimate | `lib/math/cardio_estimate.dart` | Pure functions. |
| Day and week nutrient totals | `lib/data/summary_data.dart` | Queries that sum the stored nutrient copies. |

### 2.6 Strings and the app name

- All UI text is in `S` in `lib/strings.dart`, grouped by screen with a comment per group.
- Text the native side shows (the widget's "Tap to log", the date line) is written by Dart into the widget's data, so it also comes from `S`.
- A few strings can only live in native files: the Android app label, iOS `CFBundleDisplayName`, the widget's name in the widget gallery, and the camera and health permission texts. A comment at the top of `strings.dart` lists those files, so a rename finds them.

### 2.7 Parser runtime

- `lib/parser/` is pure Dart with no Flutter imports, so all of it runs in `flutter test` and in an isolate.
- A long-lived worker isolate (`lib/parser/parse_worker.dart`) opens the USDA file itself and builds the search index at start, after the first frame (grammar 12.3).
- The main isolate sends a snapshot of the user's data (local foods, learned matches, aliases, saved meals, history counts) with a version number whenever those tables change. Typing sends only the text and the cursor.
- The worker has an inline mode that runs on the calling isolate, for widget tests (isolates do not run inside `testWidgets` fake time).

## 3. Step 0: changes to Phase 2 work

Done first, before step 1.

### 3.1 Schema decision: amend version 1

**Decision: amend schema version 1, do not add version 2.** This needs Bart's yes, because the Phase 3 summary said "a schema version bump" (open question 1).

Why:
- Nothing has been released, so no user database or backup file exists outside Bart's test installs.
- A version 2 now would need a migration step, a generated migration test, and, before any of that is useful, a way to import version 1 export files into a version 2 database. `export_import.dart` has no such path today (its comment says one is needed at v2), and an old file with `fixed_calories` would be refused as "data Daybook does not know". That is real code with no user to serve.
- The golden fixture `test/fixtures/daybook_export_v1.json` has empty `goals` and `meals` tables, so it still imports after the change.

How it passes CI: `make-migrations` refuses a changed schema under an existing version (drift_dev 2.35.2 exits with "A schema for version 1 ... already exists and differs"). The task deletes `drift_schemas/default/drift_schema_v1.json`, runs `dart run drift_dev make-migrations` to write it again, and commits it. CI then sees no diff. The guard stays meaningful: from the first store release on, any schema change must be version 2.

Cost: Bart's phone may have the Phase 2 build with a version 1 database in the old shape. It holds only cached Open Food Facts products. Uninstall it (or clear the app's data) before installing the Phase 4 build. The Phase 4 summary must say this.

**Schema changes, all of them:**

| Table | Change | Why |
|---|---|---|
| `goals` | `fixed_calories` renamed `calories` (still `INTEGER NULL`). `calorie_mode` stays: 'calculated' or 'fixed'. | Approved decision 8: the calculated number is stored when Goals is saved. |
| `meals` | New `saved_meal_id INTEGER NULL REFERENCES saved_meals(id) ON DELETE SET NULL`. Set to the first saved meal expanded in that meal (from a chip or typed). | The approved design orders saved meal chips "by how often they are used in this meal" (food-entry frame 1, speed-targets 2). A chip-logged meal has no source text, so without the column that order cannot be counted. One nullable column now costs nothing; after release it costs a migration. |

Nothing else. Checked against every frame note: custom food servings, recipe servings ("Makes 4 servings" is `base_unit` 'serving' with `base_amount` 4 and the whole pot's nutrients), planned sets, health sources, rest times and all settings fit the existing tables.

### 3.2 Food data build

- `tools/build_food_db.py` gets its sources by downloading `https://fdc.nal.usda.gov/fdc-datasets/<file>` into `build/usda-cache/` (git-ignored) when the file is missing, then checking each file's pinned SHA-256. The cache is not on the development machine now, so the first run downloads.
- Checked 2026-11-12: all three pinned files answer at that address (SR Legacy CSV 6,074,592 bytes, Foundation JSON 696,866 bytes, FNDDS JSON 3,835,292 bytes). Whether their hashes still match is only known when the script runs.
- The implementer needs network access to fdc.nal.usda.gov, Python 3 (3.14 is installed) and about 100 MB of disk. If a hash does not match, stop and report. Never change a pinned hash without Bart.
- Found in review of task 0.2: two foods also have the portions "Quantity not specified, if appetizer" and "Quantity not specified, if main course in meal". Portion pickers (task 2.9) hide every label that starts with "Quantity not specified".

### 3.3 Tasks

| Task | Owner | Builds | Files | Tests that prove it | Done when |
|---|---|---|---|---|---|
| 0.1 | Data/Nutrition | The two schema changes in 3.1 | `lib/data/database.dart`, `lib/data/database.g.dart`, `drift_schemas/default/drift_schema_v1.json` (deleted, then generated again), `docs/data-model.md`, `test/data/database_test.dart`, `test/data/export_import_test.dart`, `test/fixtures/daybook_export_v1.json` | New: a goals row keeps `calories` in both modes; deleting a saved meal sets `meals.saved_meal_id` to null. Changed: the round-trip fixture inserts (meals now have 7 columns). Golden file: add one `goals` row (with `calories`) and one meal, and check both read back. | CI schema step green. The v1 snapshot diff shows only these two changes. data-model.md says v1 was amended before release and that any later change is v2. |
| 0.2 | Data/Nutrition, after 0.1 | Keep the FNDDS "Quantity not specified" portion; rebuild the asset; hide that label in the Data check screen | `tools/build_food_db.py`, `tools/test_build_food_db.py`, `assets/food/usda.sqlite.gz`, `assets/food/usda_version.txt`, `lib/data/food_reference.dart` (add `const defaultPortionLabel = 'Quantity not specified'`), `lib/screens/data_check_screen.dart`, `test/data/food_reference_test.dart`, `test/screens/data_check_screen_test.dart`, `docs/data-model.md` | Python: `read_fndds` keeps the row with its label and seq (small zip built in the test). Dart, real asset: usda:2707153 egg has the label at 50 g, usda:2710373 coffee at 360 g, usda:2705594 half and half at 20 g; food count is still 13,598; the version string changed. Widget: the Data check portion menu does not list the label. | Grammar section 13 done. The keep is the only change to the build output. |
| 0.3 | Test, parallel with 0.1 and 0.2 | Guards for the promises, the integration test harness, and CI jobs | `test/guards_test.dart`, `integration_test/app_launch_test.dart`, `pubspec.yaml` (dev: `integration_test` from the SDK), `.github/workflows/ci.yml`, `tools/allowed_permissions.txt`, `docs/dependencies.md` | `guards_test.dart`: no `print(`, `debugPrint(` or `log(` in `lib/` outside `error_log.dart`; `package:http` imported only by `off_client.dart`; every package in `pubspec.yaml` has a row in `dependencies.md`. CI: after the APK build, the merged permissions read from the APK with `aapt2 dump permissions` must equal `tools/allowed_permissions.txt`. New CI jobs, on pushes to main and on manual run: Android emulator (API 34, plain AOSP image with no Google services) and iOS simulator, each running `integration_test/`. CI prints the size of the per-ABI release APKs. | All jobs green with the one launch test. |

## 4. Steps 1 to 8

Each table row is one task. "Frames" refers to the numbered frames on the wireframe page named. "Grammar" refers to sections of `docs/parser-grammar.md`.

### Step 1: weight entry and widget

Home and the bottom bar are built here (task 1.2), because the Weight button lives on Home. Later steps add to Home.

| Task | Owner | Builds | Files | Frames and specs | Tests that prove it |
|---|---|---|---|---|---|
| 1.1 | Data/Nutrition | Clock, units, dates, weight writes and reads, trend, units setting | `lib/clock.dart`, `lib/util/units.dart`, `lib/util/dates.dart`, `lib/data/weight_data.dart`, `lib/data/settings_data.dart`, `lib/math/weight_trend.dart`, tests under `test/util/`, `test/data/weight_data_test.dart`, `test/math/weight_trend_test.dart` | weight.html notes 1 to 7; data-model.md conventions | **Entry:** a save returns the row read back; local date and offset come from the clock. **Edit:** weight, date and time change; `updated_at_ms` moves; `created_at_ms` does not. **Delete:** sets `deleted_at_ms`; lists, latest and trend skip it; Undo clears it. **Units:** every value from 50.0 to 1,000.0 lb in steps of 0.1 survives store and display unchanged; the same for 22.7 to 453.6 kg; switching the setting changes display only, never stored values. **Range:** below 50 or above 1,000 lb (22.7 and 453.6 kg) is refused. **Time zones:** a weigh-in made at 7:00 in Tokyo (plus 9) keeps its day when the clock moves to minus 6; "today" follows the current offset; offsets minus 12 and plus 14. **Date boundaries:** 23:59:59 and 00:00:00 local land on different days; a daylight saving change day; two weigh-ins in one day; New Year. **Trend:** daily average, 10% step, deleted rows skipped, days with no weigh-in change nothing. |
| 1.2 | UI, after 1.1 | App shell with the five-tab bar, `AppScope`, Home (date header, weight row, the + Food / Weight / Cardio bar), More tab (with Data check for now), weight sheet with save, failure and Undo | `lib/app.dart`, `lib/app_scope.dart`, `lib/main.dart`, `lib/screens/home/home_screen.dart`, `lib/screens/more/more_screen.dart`, `lib/screens/weight/weight_sheet.dart`, `lib/strings.dart`, `test/app_test.dart`, `test/screens/home_screen_test.dart`, `test/screens/weight_sheet_test.dart` | index.html navigation; home.html frames 1, 3, 4 (weight row and bar only); weight.html frames 1 to 4 | Sheet opens with the last weight selected and the number pad up; Save disabled outside the range with the reason shown; the sheet closes only after the write returns and the message is built from the stored row; a failing write (a database that throws) keeps the sheet open with the number; Undo marks the entry deleted; metric shows kg; "Change" sets date and time; the layout works at 344 and 673 dp wide. |
| 1.3 | UI, after 1.2 | Weight tab: trend number, chart, range chips, list, edit, delete with Undo | `lib/screens/weight/weight_tab.dart`, `lib/screens/weight/weight_chart.dart` (a `CustomPainter`, no chart package), `lib/screens/weight/weight_sheet.dart` (edit mode), `lib/strings.dart`, `test/screens/weight_tab_test.dart` | weight.html frames 5 to 7 | List newest first; edit saves and shows "Saved"; delete removes the row at once with Undo and no popup; the trend number changes after a delete; range chips filter the chart; a source label shows for imported rows (data made directly in the test). |
| 1.4 | UI, after 1.3 | Android home-screen widget; the app writes the widget's data on every weight save, edit, delete, Undo and at start; a widget tap opens the weight sheet | `pubspec.yaml` (home_widget), `docs/dependencies.md`, `lib/platform/weight_widget.dart`, `lib/app.dart` (launch link), `android/app/src/main/kotlin/io/github/bartbasi/daybook/WeightWidgetProvider.kt`, `android/app/src/main/res/layout/weight_widget.xml`, `android/app/src/main/res/layout/weight_widget_small.xml`, `android/app/src/main/res/xml/weight_widget_info.xml`, `android/app/src/main/AndroidManifest.xml`, `test/platform/weight_widget_test.dart`, `integration_test/widget_launch_test.dart` | weight.html frames 8, 9 | Mocked channel: after a save the widget data holds the weight, its date, the trend and "Tap to log" in the current units, and an update is requested; the widget never writes. The launch link `daybook://weight` opens the sheet over Home (widget test, and on the emulator by starting the app with that link). The widget is resizable down to 2 by 1 cells. |
| 1.5 | UI, parallel with 1.6 | iOS widget extension (WidgetKit, SwiftUI), App Group shared data, tap opens the sheet | `ios/WeightWidget/WeightWidget.swift`, `ios/WeightWidget/Info.plist`, `ios/WeightWidget/WeightWidget.entitlements`, `ios/Runner/Runner.entitlements`, `ios/Runner.xcodeproj/project.pbxproj`, `tools/ios/add_widget_target.rb`, `.github/workflows/ios-widget-target.yml`, `.github/workflows/ci.yml` (one check step), `lib/platform/weight_widget.dart` (App Group id) | weight.html frame 10 | See risk 1 for the method. CI: the unsigned iOS build passes and `Runner.app/PlugIns/WeightWidget.appex` exists after it. The widget reads only the App Group data the app writes. Bundle id `io.github.bartbasi.daybook.WeightWidget`, App Group `group.io.github.bartbasi.daybook`. |
| 1.6 | Test, parallel with 1.5 | Speed target 3 and an independent pass over weight reliability | `test/speed/tap_counter.dart`, `test/speed/weight_speed_test.dart`, `integration_test/flows/weight_flow.dart`, `integration_test/weight_test.dart`, `test/data/weight_reliability_test.dart` | speed-targets.md section 3 | From Home: 2 counted taps plus 5 keys gives one stored row of 181.8 lb. From the widget link: 1 counted tap (Save) after the launch. Save tapped twice fast writes one row. Folding (a width change from 344 to 673 dp) keeps the typed number. Closing and reopening the database keeps every saved row. |

Step 1 acceptance (BRIEF.md): writes go to the database at once and are confirmed on screen; entry from Home in 2 taps; a home-screen widget on both platforms; a trend line; tests cover entry, edit, delete, unit switching, time zone changes and date boundaries.

### Step 2: food parser and one-screen meal entry

Covers saved meals, aliases, recents, same as yesterday and barcode. The Data check screen is removed at the end of this step (task 2.13), when Food entry and the correction sheet show real food numbers.

**Found in review of task 2.7, for the screen tasks.** (1) Deleting a meal or a saved meal is a real delete; Undo re-inserts rows held in memory. The screen must drop the held rows after one Undo, and task 8.2 must discard any pending Undo when Import runs. (2) A reopened recipe's ingredient lines come back without nutrients (the schema has no copies for them), so task 2.12 must recompute each ingredient's nutrients from the food data before saving; the data layer refuses an ingredient with none. (3) The data layer's files are `lib/data/food_data.dart` (meals, the day, recents, the snapshot) and `lib/data/food_library_data.dart` (saved meals, aliases, custom foods, recipes); the plain snapshot types are in `lib/parser/user_snapshot_data.dart`. (4) Alias phrases and saved meal names are compared through `nameKey` in `lib/parser/name_key.dart`, the one function both sides use.

**Widget link over a full screen.** Found in review of task 1.4: the weight widget's link opens the weight sheet through Home, so if Food entry (or any full screen) is on top, the sheet opens over it and Home's "Weight saved" bar is hidden underneath. Task 2.8 must decide and test what a widget tap does while Food entry is open, without losing typed text.

**Line type.** Task 2.1 creates `lib/parser/line.dart` with the one data class every later task uses: food ref and name, quantity, unit label, base quantity and unit, nutrients (map of nutrient id to amount for this line), state (grammar 8.1), markers (Guess, Assumed, Your pick, Scanned), learned key, the text span, and for saved meals the header with its item lines. Later tasks add fields only through the reviewer.

| Task | Owner | Builds | Files | Grammar and frames | Tests that prove it |
|---|---|---|---|---|---|
| 2.1 | Data/Nutrition | Text clean-up, hard and soft splitting, protected phrases, number phrases, dictation splitting, quantities, multipliers, ranges, units, sizes, "of"; the line type | `lib/parser/line.dart`, `lib/parser/tokens.dart` (every fixed list in 10.2 and 2.3, and the synonym table in 5.3), `lib/parser/clean.dart`, `lib/parser/split.dart`, `lib/parser/amount.dart`, `test/parser/clean_test.dart`, `test/parser/split_test.dart`, `test/parser/amount_test.dart` | Sections 2, 3, 4.1 to 4.3, 10 | One test per row of the 2.1 table and per rule in 2.6; every form in 3.1; 3.2 to 3.5; every unit spelling in 4.1; each case in 4.2; each built-in protected phrase stays whole; the "Read items" column of 2.7; item count, quantity and unit for examples 1, 2, 16 to 30, 33 to 39, 43 to 46, 61 to 71 and 76 to 88. |
| 2.2 | Test, parallel with 2.1 | The 88 worked examples as data, and their fixtures | `test/parser/worked_examples.dart`, `test/parser/worked_examples_test.dart` (skipped until 2.5) | Section 11 | Transcribed from 11.2 by someone who did not write the parser. Pass rules from 11.1: same number of lines, same state and food ref per line, grams within 0.05, kcal within 0.5. Fixtures from 11.1 (saved meals, user foods, learned rows, history). |
| 2.3 | Data/Nutrition, after 2.1 | Portions, typed unit to grams, default amount, what a line stores, nutrient scaling | `lib/parser/portions.dart`, `lib/parser/grams.dart`, `test/parser/portions_test.dart`, `test/parser/grams_test.dart` | 4.4 to 4.7 | Label reading cases in 4.4; each rule of 4.5 and 4.6 in order, on a small in-memory reference database; on the real asset: egg 50 g, coffee "1 small" 360 g, half and half 1 tbsp 15 g, milk 500 ml 515.7 g, sourdough toast 2 slices 56 g; local food base units 'ml' and 'serving'. |
| 2.4 | Data/Nutrition, parallel with 2.3 | Normalizing, synonyms, the search index, candidates, ranking, matched or guess, the correction-sheet search | `lib/parser/normalize.dart`, `lib/parser/search_index.dart`, `lib/parser/rank.dart`, `test/parser/normalize_test.dart`, `test/parser/rank_test.dart` | 5.1 to 5.7 | Plural rules; filler and negation; joined word pairs ("sourdough"); typo limits and tie rules with the four examples; each synonym gives the food 5.3 says; the 5.6 table on the real asset; key 2 "fits" with the chili and cookies fixtures; the 10% energy tie rule; the sheet search lists foods matching one word, top 20. |
| 2.5 | Data/Nutrition, after 2.3 and 2.4 | Aliases and saved meals, learned matches (key and apply), line states, the whole `parseMeal(text, cursor, snapshot)`, the user data snapshot; turn on the 88 examples | `lib/parser/parser.dart`, `lib/parser/user_snapshot.dart`, `lib/parser/learned_key.dart`, `test/parser/worked_examples_test.dart` (remove the skip), `test/parser/parser_test.dart`, `test/parser/benchmark_test.dart` | 6, 7.1, 7.3, 8.1, 12.1, 12.2 (the spoken label text of 8.2 is built by the screen in task 2.8, since only UI tasks edit `strings.dart`) | All 88 examples pass. Learned key examples in 7.1. Alias beats saved meal name; newest saved meal wins a name tie. Benchmark on CI: index build under 1.5 s; re-parse after one keystroke while typing example 1 one character at a time, p95 under 8 ms; a 10-item parse under 25 ms. (Half the phone targets, because the CI machine is faster than the phone. The phone check is in section 7.) |
| 2.6 | Data/Nutrition, after 2.5 | Live re-parsing: item cache, sticky corrections across edits, the half-typed item, the worker isolate with stale results dropped and an inline mode | `lib/parser/parse_session.dart`, `lib/parser/parse_worker.dart`, `test/parser/parse_session_test.dart`, `test/parser/parse_worker_test.dart` | 9.1, 9.2, 12.3 | The three 9.1 cases; span shifting before and after an edit; key change drops a pick; the cursor rule in 9.2 and example 62; an older result arriving after a newer one is ignored; a snapshot version change clears the cache. |
| 2.7 | Data/Nutrition, parallel with 2.1 to 2.6 | Food data: save a meal in one transaction (meal, entries, nutrient copies, learned matches, `saved_meal_id`), edit a meal keeping untouched lines byte for byte, delete with Undo, same as yesterday, recent and frequent foods, default meal by time, saved meals and aliases, custom foods and recipes, history counts, forget a learned match, the snapshot loader | `lib/data/food_data.dart`, `test/data/food_data_test.dart` | 4.7, 7.2, 7.4, 9.3; food-entry notes 1, 11 to 13; saved-meals notes; food-editor notes | Save writes everything or nothing (a forced failure leaves no rows). Learning on Save follows each row of the 7.2 table; nothing learned when not saved; corrections inside a saved meal never learned. Editing changes only touched lines. Undo of a delete restores the same rows. "Same as yesterday" is yesterday's same slot, absent when empty. Alias phrases are unique across saved meals. Default slot at 10:29, 10:30, 14:30, 17:00, 21:00 and 23:59. Custom food with a serving weight stores `base_unit` 'g' plus a "1 serving" portion; without one, 'serving'. Recipe "makes 4" stores `base_amount` 4 servings and the whole pot's nutrients. Recent and frequent chips (decision): foods logged in this slot in the last 30 days, most logged first, then most recent, up to 8, each with its last amount. |
| 2.8 | UI, after 2.6 and 2.7 | Food entry screen: date and meal chips, the text box, live lines with markers, the totals bar, Save and "Fix N items", close with Undo on Home, edit a logged meal, the menu (Delete meal, Save as a saved meal); Home meal rows and the + Food button | `lib/screens/food/food_entry_screen.dart`, `lib/screens/food/food_line_tile.dart`, `lib/screens/home/home_screen.dart`, `lib/strings.dart`, `test/screens/food_entry_screen_test.dart` | food-entry frames 1, 2, 3, 6a, 6b, 11, 13; home frames 1, 2 (meal rows); grammar 8.1, 8.2, 8.4, 9.3 | Opens with focus in the box and the meal from the clock; lines update on every change with no delay; Save disabled with no lines; a not found item under the cursor is drawn plain and not counted; "Fix 1 item" opens that line; a save failure keeps everything with the message from frame 11; close with text offers Undo that restores text and lines; editing a meal shows its entries as added lines and an empty box; each marker has its word and its spoken label. |
| 2.9 | UI, after 2.8 | Correction sheet: candidates, search, amount and unit picker (hiding "Quantity not specified"), Forget this match, Remove from meal; the not found sheet | `lib/screens/food/correction_sheet.dart`, `lib/screens/food/food_entry_screen.dart`, `lib/strings.dart`, `test/screens/correction_sheet_test.dart` | food-entry frames 4, 5, 7; grammar 8.3 | Current pick first then up to 7; picking makes a sticky correction marked "Your pick"; changing the amount on a typed line rewrites only numbers and unit in the text; Remove deletes the item's text; Forget appears only for learned lines and acts at once; the not found sheet's search starts with the typed words. "Scan its barcode" and "Create a food" are wired in 2.11 and 2.12. |
| 2.10 | UI, after 2.9 | Chips row (Same as yesterday, saved meals ordered by use in this slot, recent and frequent foods), whole-meal chips log at once with Undo when the screen is empty, otherwise add lines; Saved meals list and editor under More | `lib/screens/food/meal_chips.dart`, `lib/screens/food/food_entry_screen.dart`, `lib/screens/saved_meals/saved_meals_screen.dart`, `lib/screens/saved_meals/saved_meal_editor.dart`, `lib/screens/more/more_screen.dart`, `lib/strings.dart`, tests for each screen | food-entry frames 1, 8, 12; saved-meals frames 1, 2; grammar 6.4 | Whole-meal chip with an empty box logs, closes, and Home shows the message with Undo for 10 seconds; with text, the label reads "Tap adds its items" and a tap adds a header with item lines; a food chip adds one line with the last amount; a typed alias shows the header and items; header multiplier edit rewrites the quantity in the text; a duplicate alias is refused with a plain message. |
| 2.11 | UI, after 2.10 | Barcode scan screen (camera, permission asked on first use), lookup through the existing `OffClient`, the added "Scanned" line with the credit, "not found" and "no connection" messages, "Scan its barcode" in the not found sheet | `pubspec.yaml` (flutter_zxing), `docs/dependencies.md`, `lib/platform/barcode.dart`, `lib/screens/food/barcode_scan_screen.dart`, `lib/screens/food/food_entry_screen.dart`, `lib/screens/food/correction_sheet.dart`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `tools/allowed_permissions.txt`, `lib/strings.dart`, `test/screens/barcode_flow_test.dart` | food-entry frames 9, 10; grammar 9.3 (barcode row) | A found product adds an added line, marked Scanned, 1 serving; a scanned product is cached and can then be found by typing; not found offers "Add it as your own food" with the barcode filled in; no connection adds nothing; no product image is fetched; the HTTP mock shows exactly one request per scan with the agreed User-Agent. Manifest: CAMERA kept; the plugin's RECORD_AUDIO and WRITE_EXTERNAL_STORAGE removed with `tools:node="remove"`; camera feature marked not required. iOS: camera usage text, and the microphone and photo library texts that App Store checks need (see risk 7). |
| 2.12 | UI, after 2.11 | Custom food editor (also from "Create a food" and from a barcode not found), recipe editor, My foods and recipes list under More | `lib/screens/my_foods/my_foods_screen.dart`, `lib/screens/my_foods/food_editor.dart`, `lib/screens/my_foods/recipe_editor.dart`, `lib/screens/food/correction_sheet.dart`, `lib/screens/more/more_screen.dart`, `lib/strings.dart`, tests for each | food-editor frames 1, 2 | Name, amount and calories required; empty nutrients stored as absent and shown "not listed", never 0; per serving, per 100 g or per 100 ml; saving from a not found line returns with the line matched and "Your pick"; a recipe's ingredients are added lines and the box adds more; "2 servings chili" matches the recipe (example 74). |
| 2.13 | UI, after 2.12 | Remove the temporary Data check screen | delete `lib/screens/data_check_screen.dart` and `test/screens/data_check_screen_test.dart`; `lib/screens/more/more_screen.dart`, `lib/strings.dart` (remove its strings), `lib/data/food_reference.dart` and `test/data/food_reference_test.dart` (drop `search` and its test if nothing else uses it), `test/guards_test.dart` (remove the temporary allow-list line for the Data check screen), `integration_test/app_launch_test.dart` if it still refers to that screen | | `flutter analyze` clean; no dead strings left. |
| 2.14 | Test, after 2.12 | Speed targets 1 and 2, and an independent pass over food logging | `test/speed/food_speed_test.dart`, `integration_test/flows/food_flow.dart`, `integration_test/food_test.dart`, `test/data/food_logging_test.dart` | speed-targets.md sections 1, 2 | Brief's meal: 2 counted taps, 5 entries, 490 kcal stored. Saved meal chip and Same as yesterday: 2 counted taps. Undo after each removes exactly that meal. Editing a meal and saving without changes leaves every stored value identical. |

Step 2 acceptance (BRIEF.md): one tap opens entry, nothing in between; date and meal changeable with one tap; live lines with food, amount, kcal and macros; tap a line to change it; Save saves the whole meal; on the device only; learns from corrections; saved meals and aliases expand; recents, frequents and same as yesterday on the same screen; barcode adds a line; default meal by time.

### Step 3: goals and the daily calorie budget

| Task | Owner | Builds | Files | Frames and specs | Tests that prove it |
|---|---|---|---|---|---|
| 3.1 | Data/Nutrition | Mifflin-St Jeor, activity factors (1.2, 1.375, 1.55, 1.725, 1.9), rate at 3,500 kcal per lb, own number, low-intake warning (under 1,500 men, 1,200 women), macros in grams or percent, add-back 0, 50, 100%; goals saved by `effective_from` with Recalculate; the day's budget; Daily Values as default nutrient goals | `lib/math/calorie_budget.dart`, `lib/data/goal_data.dart`, `lib/data/nutrients.dart` (Daily Values), `test/math/calorie_budget_test.dart`, `test/data/goal_data_test.dart` | goals.html notes 1 to 5; home.html note 1 (budget sum); decisions 6 and 8 | Sample person: 1,736.8, 2,388, 2,138 (round only the shown numbers). Percent mode: 160 g, 214 g, 71 g. Percents must add to 100. A day uses the goals row with the latest `effective_from` on or before it; saving twice on one day updates that row; past days keep theirs. Budget = goal + add-back x exercise (override first, else estimate; deleted cardio left out) minus food; 0, 50 and 100%. Weight comes from the latest weigh-in on or before the save day. Daily Values are the FDA values for adults and children 4 and over (21 CFR 101.9); total sugar and trans fat get no default goal. Metric (decision): the same five rates shown in kg. |
| 3.2 | UI, after 3.1 | Goals screen with the working shown, the warning, own number, add-back, macros, Other nutrients list; Home budget card, macro meters, "Set your goals" card; the "left today" figure in the Food entry bar | `lib/screens/goals/goals_screen.dart`, `lib/screens/goals/other_nutrients_screen.dart`, `lib/screens/home/home_screen.dart`, `lib/screens/food/food_entry_screen.dart`, `lib/screens/more/more_screen.dart`, `lib/strings.dart`, tests for each | goals.html frames 1 to 5; home.html frames 1, 2 (budget card and meters) | The warning is one sentence with no color or icon and never blocks Save; "Use my own calorie goal" keeps the inputs; grams mode shows each macro in kcal and the difference from the goal; Home shows "Set your goals" until goals exist; the line under the big number always shows the sum. |
| 3.3 | Test, after 3.2 | Budget across days and goal changes | `test/data/budget_scenarios_test.dart` | home.html frame 2 numbers | With rows inserted directly (a 383 kcal run, the sample meals): 2,138 + 383 minus 1,266 = 1,255. Goals changed mid-week leave earlier days alone. A cardio row deleted after the fact drops its add-back. |

Step 3 acceptance (BRIEF.md): Mifflin-St Jeor times activity, adjusted for rate; own fixed number; exercise calories added at 0, 50 or 100% (default 100); macros as grams or percent; plain low-intake warning, no blocking.

### Step 4: resistance training

| Task | Owner | Builds | Files | Frames and specs | Tests that prove it |
|---|---|---|---|---|---|
| 4.1 | Data/Nutrition | The wger exercise asset and its loader (see section 6.1) | `tools/build_exercise_data.py`, `tools/test_build_exercise_data.py`, `assets/exercises/wger_exercises.json`, `assets/exercises/README.txt`, `pubspec.yaml` (asset folder), `lib/data/exercise_library.dart`, `test/data/exercise_library_test.dart`, `docs/data-sources.md` | data-sources.md wger section; routine-editor note 2 | Python: HTML stripped, email authors replaced by "wger.de contributor", license per entry kept. Dart: loads all entries; search by name and alias; one muscle filter; user exercises merged in; `wger:<id>` refs resolve. |
| 4.2 | Data/Nutrition, parallel with 4.1 | Workouts: start from a routine or a past workout (planned set rows stored prefilled), log a set, adjust, remove a set, finish (planned sets not logged deleted, calories 3.5 MET x kg x hours), resume, the "Start again" order, one running workout; Epley, records, weekly volume | `lib/data/workout_data.dart`, `lib/math/training.dart`, `test/data/workout_data_test.dart`, `test/math/training_test.dart` | workout.html notes 1 to 6 and its decisions; exercise-detail notes | Prefill uses the last time each exercise was done; first time empty. Logging marks the stored row completed at once; closing and reopening the database loses nothing. "Start again": yesterday first, same weekday last week second, then others. Epley only for 1 to 12 reps; 180 x 8 gives 228 lb. Records: heaviest weight and best Epley. Volume: completed sets per primary muscle, Monday to Sunday. Finish with 2 planned sets not logged removes them and Resume brings them back. |
| 4.3 | UI, after 4.2 | Workouts tab, active workout, adjust sheet (+5/-5 lb or 2.5 kg, +1/-1 reps), New record label, finish summary, in-app rest timer with vibration, "Return to workout" on Home and the tab | `lib/screens/workouts/workouts_tab.dart`, `lib/screens/workouts/workout_screen.dart`, `lib/screens/workouts/set_sheet.dart`, `lib/screens/workouts/rest_timer_bar.dart`, `lib/screens/workouts/finish_screen.dart`, `lib/screens/home/home_screen.dart`, `lib/strings.dart`, tests for each | workout.html frames 1 to 6; home.html note 2 (workout bar) | One tap on the check logs exactly what is shown and starts the timer with the routine's rest; the list scrolls to the next set; -15 s, +15 s, Skip; logging the next set ends the timer; no permission prompt anywhere in this path (mocked channels show no permission call). |
| 4.4 | UI, after 4.3 | Routine editor, exercise picker (shared with "+ Add exercise"), create exercise, exercise detail with records and wger credit, weekly volume screen, More > Exercises | `lib/screens/workouts/routine_editor.dart`, `lib/screens/workouts/exercise_picker.dart`, `lib/screens/workouts/exercise_detail.dart`, `lib/screens/workouts/weekly_volume_screen.dart`, `lib/screens/more/more_screen.dart`, `lib/strings.dart`, tests for each | routine-editor frames 1, 2; exercise-detail frames 1, 2 | Reorder by drag; sets and rest per exercise; the picker stays open after Add; recent exercises first; detail shows each entry's author and license, never an email address. |
| 4.5 | UI, after 4.4 | "Alert me when rest ends": asks for notification permission only when tapped, then schedules "Rest done" for the end of each rest and cancels it on Skip or the next set | `pubspec.yaml` (flutter_local_notifications, timezone), `docs/dependencies.md`, `lib/platform/rest_alert.dart`, `lib/screens/workouts/rest_timer_bar.dart`, `lib/data/settings_data.dart` (one key), `android/app/build.gradle.kts` (core library desugaring, which the plugin needs), `android/app/src/main/AndroidManifest.xml`, `tools/allowed_permissions.txt`, `lib/strings.dart`, `test/platform/rest_alert_test.dart` | workout.html frame 3 and the rest timer decision | No permission call until the row is tapped; then one scheduled notification per rest at the right time (UTC); cancelled on Skip and on the next set. Android schedule mode: see open question 6. |
| 4.6 | Test, after 4.5 | Speed targets 4 and 5, workout crash safety | `test/speed/workout_speed_test.dart`, `integration_test/flows/workout_flow.dart`, `integration_test/workout_test.dart` | speed-targets.md sections 4, 5 | From the Workouts tab, 1 counted tap starts yesterday's workout and 1 starts last week's, with every set prefilled. 1 counted tap logs a prefilled set. A workout survives an app restart in the middle. |

Step 4 acceptance (BRIEF.md): open-licensed library plus user exercises; routines with every set prefilled; rest timer, personal records, estimated 1-rep max, weekly volume per muscle group; repeat a previous workout in one tap.

### Step 5: cardio with MET estimates

| Task | Owner | Builds | Files | Frames and specs | Tests that prove it |
|---|---|---|---|---|---|
| 5.1 | Data/Nutrition | The Compendium MET asset and loader, activity groups with speed bands (see section 6.2) | `tools/build_met_table.py`, `tools/test_build_met_table.py`, `assets/met/compendium_2024.csv`, `assets/met/README.txt`, `pubspec.yaml` (asset folder), `lib/data/met_table.dart`, `test/data/met_table_test.dart`, `docs/data-sources.md` | data-sources.md Compendium section; cardio.html note 2 | Python: pinned PDF hash; row count matches the Compendium's 1,114 activities (or the script says which are missing); spot checks 12050 = 9.3, 02054 = 3.5, 12060 = 10.5, 17190 = 3.8. Dart: every row loads; codes are unique; groups list their bands in order. |
| 5.2 | Data/Nutrition, after 5.1 | Band choice (the band holding the pace; in a gap, the nearest band edge; on a tie, the slower), estimate gross MET x kg x hours, cardio save, edit, soft delete and Undo, up to 3 recent activities, the entry used last time per activity | `lib/math/cardio_estimate.dart`, `lib/data/cardio_data.dart`, `test/math/cardio_estimate_test.dart`, `test/data/cardio_data_test.dart` | cardio.html notes 1 to 5; decisions 6 and 7 | 3.1 mi in 30 min is 6.2 mph, code 12050, 9.3 x 82.46 kg x 0.5 h = 383 kcal; a pace in a gap and an exact tie; values never blended; with no distance, last time's entry, else the group's general entry; body weight is the latest weigh-in on or before the session's day, and with none the estimate is empty (the user types a number); override and estimate both stored; deleted rows skipped everywhere. |
| 5.3 | UI, after 5.2 | Cardio screen (one screen), Other... search, override with "Use estimate", Home Cardio button and exercise rows, "Log cardio" on the Workouts tab, edit and delete with Undo | `lib/screens/cardio/cardio_screen.dart`, `lib/screens/cardio/activity_search.dart`, `lib/screens/home/home_screen.dart`, `lib/screens/workouts/workouts_tab.dart`, `lib/strings.dart`, tests for each | cardio.html frames 1 to 5 | Last activity preselected and Duration focused; first use shows only Other...; the estimate updates while typing; the bar says "your number" or "estimate"; Change lists the group's other entries; heart rate stored, not used. |
| 5.4 | Test, after 5.3 | Speed target 6 | `test/speed/cardio_speed_test.dart`, `integration_test/flows/cardio_flow.dart`, `integration_test/cardio_test.dart` | speed-targets.md section 6 | 3 counted taps (open, the keyboard Next action or the Distance field, Save) and no second screen pushed (a `NavigatorObserver` counts routes); stored 383 kcal. |

Step 5 acceptance (BRIEF.md): activity, duration, optional distance and heart rate; burn from MET, body weight and duration, shown and overridable.

### Step 6: summaries and micronutrient views

| Task | Owner | Builds | Files | Frames and specs | Tests that prove it |
|---|---|---|---|---|---|
| 6.1 | Data/Nutrition | Day totals for every tracked nutrient (unrounded), "not listed" when no entry that day has the nutrient, top foods per nutrient with share, the week Monday to Sunday with each day's own budget, averages over days with food | `lib/data/summary_data.dart`, `test/data/summary_data_test.dart` | summary.html notes 1 to 3 | Fat 48.52 g of 70 is 69%; shares add to 100%; over goal reports the percent above 100; week averages skip days with no food; each day uses its own goals row. |
| 6.2 | UI, after 6.1 | Summary tab: day view with bars and "Over" (hatched, not color), nutrient detail with top foods, week view with day bars and budget lines; Home budget card opens today's Summary; a food opens its meal | `lib/screens/summary/summary_tab.dart`, `lib/screens/summary/nutrient_detail_screen.dart`, `lib/screens/summary/week_view.dart`, `lib/screens/home/home_screen.dart`, `lib/strings.dart`, tests for each | summary.html frames 1 to 3 | < and > move a day or week; the day's numbers equal Home's; "not listed" shown as words. |
| 6.3 | Test, after 6.2 | The sample day end to end | `test/scenarios/sample_day_test.dart` | home.html frame 2, summary.html frame 1 | Breakfast typed as the brief's meal and a 30 minute 3.1 mi run through the real parser and data code: 1,266 eaten of 2,521, 1,255 left, the same on Home and Summary. |

Step 6 acceptance (BRIEF.md): daily and weekly totals against goals, and which foods gave the most of each nutrient.

### Step 7: Health Connect and Apple Health sync (optional, off by default)

| Task | Owner | Builds | Files | Frames and specs | Tests that prove it |
|---|---|---|---|---|---|
| 7.1 | Data/Nutrition | Reading weigh-ins and workouts when sync is on: at the moment it is turned on (last 30 days), at app start and on resume. Weigh-ins into `weight_entries`, workouts into `cardio_sessions`, each with `source` and `source_id`, insert or ignore, so a deleted row never comes back. Native setup on both platforms. | `pubspec.yaml` (health), `docs/dependencies.md`, `lib/platform/health_sync.dart`, `lib/data/settings_data.dart` (keys), `android/app/src/main/kotlin/io/github/bartbasi/daybook/MainActivity.kt` (becomes `FlutterFragmentActivity`), `android/app/build.gradle.kts` (minSdk 26), `android/app/src/main/AndroidManifest.xml` (READ_WEIGHT, READ_EXERCISE, READ_DISTANCE, READ_TOTAL_CALORIES_BURNED, the permissions rationale intent filter and activity alias, the Health Connect package query), `tools/allowed_permissions.txt`, `ios/Runner/Info.plist` (health usage texts), `ios/Runner/Runner.entitlements` (HealthKit), `ios/Runner.xcodeproj/project.pbxproj` (entitlements setting if 1.5 did not add it), `test/platform/health_sync_test.dart` | settings.html frame 5; weight.html note 5; cardio.html note 5 | Off by default: with sync off there is no call on the health channel at all. Import twice gives no duplicates. A deleted imported row stays deleted after the next import. Weights in kg stored as given; local date from the record's time in the phone's current offset. Workout calories: open question 5. |
| 7.2 | UI, after 7.1 | A Settings screen with only the Health section for now (Health Connect on Android, Apple Health on iPhone, per-type switches, "Last read"); source labels on weight rows and cardio rows | `lib/screens/more/settings_screen.dart` (new), `lib/screens/more/more_screen.dart`, `lib/screens/weight/weight_tab.dart`, `lib/screens/home/home_screen.dart`, `lib/strings.dart`, `test/screens/settings_health_test.dart` | settings.html frames 2 and 5 (Health part) | Turning it on shows the system permission screen first (mocked); each type turns off on its own; the text says nothing is sent anywhere else. |

Step 7 acceptance (BRIEF.md): optional, off by default; smart-scale weigh-ins arrive; workouts can be imported; no other network call.

### Step 8: About, settings, units

| Task | Owner | Builds | Files | Frames and specs | Tests that prove it |
|---|---|---|---|---|---|
| 8.1 | Data/Nutrition | Meal slots (rename, add, reorder, archive) and their time rules; export file name `daybook-YYYY-MM-DD.zip`; a check that reads an export and returns its date and counts (meals, weigh-ins, workouts) for the Import confirmation without importing | `lib/data/settings_data.dart`, `lib/data/export_import.dart`, `test/data/settings_data_test.dart`, `test/data/export_import_test.dart` | settings.html notes 3, 4 | Archived slots keep past meals; rules apply until the next rule; the counts match the file; a bad file is refused before the dialog. |
| 8.2 | UI, after 8.1 | Settings: units switch, meal slots screen, Export (the phone's own save dialog) and Import (pick a file, the one confirmation with "Export first") | `pubspec.yaml` (file_picker), `docs/dependencies.md`, `lib/screens/more/settings_screen.dart`, `lib/screens/more/meal_slots_screen.dart`, `lib/strings.dart`, tests for each | settings.html frames 2, 3, 4 | Units switch changes every screen's display and no stored value; export then import through the UI (mocked file channel) gives the same data; a bad file changes nothing and says why. |
| 8.3 | UI, after 8.2 | About (version, author line from NOTICE word for word, Send feedback, Source code, License, data credits copied from data-sources.md, Buy Me a Coffee as the last row) and the License page (NOTICE, GPL v3 text, third-party licenses) | `pubspec.yaml` (url_launcher; LICENSE and NOTICE as assets), `docs/dependencies.md`, `lib/screens/more/about_screen.dart`, `lib/screens/more/license_screen.dart`, `lib/screens/more/more_screen.dart`, `android/app/src/main/AndroidManifest.xml` (queries for mailto and https), `ios/Runner/Info.plist` (mailto scheme), `lib/strings.dart`, `test/screens/about_screen_test.dart` | about.html frames 1 to 3 | Feedback opens `mailto:bartbasi@gmail.com` with subject "Daybook 1.0.0 feedback" built from `appName` and `appVersion` and nothing else; every credit text matches data-sources.md exactly; Buy Me a Coffee appears only here. |
| 8.4 | Test, after 8.3 | Final speed-target run, units across screens, export and import from the UI | `test/speed/all_targets_test.dart`, `integration_test/all_targets_test.dart`, `test/screens/units_switch_test.dart` | speed-targets.md | All six targets pass under `flutter test` and on the emulator and simulator in CI. |
| 8.5 | Lead | `docs/phase-4-summary.md`: what was built, the test and CI results, the size report, everything not finished (at least: MyFitnessPal import, skipped by Bart's Phase 1 decision 7), the phone checklist from section 7.3 for Bart, and the note to uninstall the Phase 2 build first | `docs/phase-4-summary.md` | | Reviewer checks it against this plan. |

Step 8 acceptance (BRIEF.md): pounds and inches by default with a metric option; export and import from the app; About with version, source link, license, food data attribution, Buy Me a Coffee row and Send feedback; meal slots editable.

## 5. Dependencies

Checked on pub.dev on 2026-11-12 (version and license tags from the pub.dev API; native dependencies read from each package's published archive). MIT, BSD-2-Clause, BSD-3-Clause and Apache-2.0 are all compatible with GPL-3.0. None of these packages has analytics, crash reporting or ads, and none makes a network call in the way Daybook uses it.

| Package | Version | License | For | Step | Notes |
|---|---|---|---|---|---|
| home_widget | 0.10.0 | BSD-3-Clause | Home-screen widget data and launch on both platforms | 1 | Native side uses AndroidX only (core, work, coroutines). Supports Swift Package Manager. |
| flutter_zxing | 3.1.1 | MIT; bundles zxing-cpp (Apache-2.0, some files BSD-3-Clause) | Barcode scanning on the device | 2 | Pulls in camera 0.12.2 (BSD-3-Clause; Android uses CameraX, Apache-2.0), image 4.12.0 (MIT), image_picker 1.2.4 (Apache-2.0 and BSD-3-Clause), ffi (BSD-3-Clause). Ships a Package.swift for iOS. |
| flutter_local_notifications | 23.0.1 | BSD-3-Clause | "Rest done" alert, only after the user asks | 4 | Needs core library desugaring on Android. |
| timezone | 0.11.2 | BSD-2-Clause | Time for scheduled notifications (UTC only) | 4 | Already pulled in by flutter_local_notifications. |
| health | 13.3.2 | MIT | Health Connect and Apple Health reads | 7 | Pulls in carp_serializable 3.0.0 (MIT), device_info_plus 13.3.0 (BSD-3-Clause), intl 0.20.3 (BSD-3-Clause), json_annotation 4.12.0 (BSD-3-Clause), and on Android androidx.health.connect connect-client (Apache-2.0). Requires Android minSdk 26. |
| file_picker | 13.3.3 | MIT | Export (save dialog) and Import (pick a file) | 8 | Pulls in android_file_picker 2.1.6 (MIT), file_picker_darwin 2.5.1 (MIT), cross_file 0.4.0 (BSD-3-Clause). One package covers both directions, so share_plus is not needed. |
| url_launcher | 6.3.3 | BSD-3-Clause | Links and the mail app in About | 8 | |
| integration_test (SDK) | with Flutter 3.47.7 | BSD-3-Clause | Tests on the emulator and simulator | 0 | Dev only. |
| reactivecircus/android-emulator-runner (CI action) | v2.38.0 | Apache-2.0 | Android emulator job | 0 | CI only. |

**No package** for: state management, routing, charts (the weight chart and week bars are a `CustomPainter` and plain widgets), the clock (a function type), vibration at the end of a rest (`HapticFeedback`), sharing.

### Barcode scanning: what was checked

| Option | Result |
|---|---|
| mobile_scanner 7.5.0 (BSD-3-Clause) | Rejected for Android. Its README says it uses "by default the bundled version of MLKit Barcode-scanning for Android", with an unbundled option "downloaded on first use via Google Play Services", and no other Android engine. Google's ML Kit data disclosure page says ML Kit collects device information, application information, performance metrics and error codes, "Used for diagnostics and usage analytics", sent over HTTPS. That breaks "collects no data" and adds a network call. ML Kit is a closed Google binary under Google's terms, not an open license, and the unbundled model needs Google Play services. (On iOS it uses Apple's Vision framework, which would be fine, but one package for both is simpler.) |
| **flutter_zxing 3.1.1 (MIT), chosen** | Decodes on the device with zxing-cpp compiled into the app (Android through CMake and the NDK, iOS from sources included in the package). Read in the 3.1.1 archive: 261 zxing-cpp files are Apache-2.0 and 11 are BSD-3-Clause; the bundled zint encoder has a BSD-style license. No Google Play services or ML Kit anywhere. The only network code is `readBarcodeImageUrl`, which Daybook never calls (task 2.11 tests the HTTP mock sees only the Open Food Facts request). Reads EAN-13, EAN-8, UPC-A and UPC-E. Android minimum API 23, iOS 13. Published 2026-11-09, so it is maintained. |
| zxing2 0.2.4 (BSD-3-Clause), fallback | A pure Dart port of ZXing, used with the camera package's image stream. No native build at all. Last release June 2025, and decoding in Dart is slower. Use it only if flutter_zxing will not build in CI. |

## 6. Reference data still to load

### 6.1 wger exercise library (step 4, task 4.1)

| Item | Plan |
|---|---|
| Source | The wger API `https://wger.de/api/v2/exerciseinfo/`, fetched once by `tools/build_exercise_data.py` at build time. The app never calls wger. Checked 2026-11-12: 967 exercises, all with English text; English text licenses: 819 CC BY-SA 4.0, 128 CC BY-SA 3.0, 20 CC0; 807 with muscles; 20 with an email address as author. |
| What ships | `assets/exercises/wger_exercises.json`, committed (the committed file is the pin, since the API cannot be hashed): wger id, English name and aliases, category, primary and secondary muscles (English names), equipment, the description as plain text, license short name and URL, author, and the link to the exercise on wger.de. No images and no videos. |
| License of the file | CC BY-SA, with each entry's own license. It stays a separate data file, never mixed into code. `assets/exercises/README.txt` says where it came from, the fetch date, the licenses, and the change made (HTML removed from descriptions), as CC BY-SA asks. |
| Credit | About: the wger text from data-sources.md. Exercise detail: the entry's author and license with a link; an email author shows as "wger.de contributor" (Bart, 2026-11-08). See open question 7 for the "illustrations" sentence. |
| Refs | `wger:<id>`, as data-model.md says. |

### 6.2 Compendium MET values (step 5, task 5.1)

| Item | Plan |
|---|---|
| Source | The PDF linked from pacompendium.com/adult-compendium: `https://pacompendium.com/wp-content/uploads/2025/02/1_2024-adult-compendium_1_2024.pdf`, 563,091 bytes, SHA-256 `ac30234b8f8f813837e282773cfcb3e0fe062334777c2f7b3213429c4fbc251c` (downloaded 2026-11-12). It lists major heading, code, MET and description per row. Not the journal article, which is CC BY-NC-ND. |
| Build | `tools/build_met_table.py` downloads the PDF to `build/met-cache/`, checks the hash, and turns `pdftotext -layout` output into `assets/met/compendium_2024.csv` (code, heading, MET, description, and min and max mph where a running, walking or bicycling description gives a speed). pdftotext is a build tool only (Git for Windows has it; on Ubuntu it is poppler-utils). Some rows wrap onto two lines in the text output (02054 and 02057 do), so the script must join them and the test checks spot values. |
| What ships | The CSV, MET values exactly as published, and `assets/met/README.txt` with the citation and "values unchanged". |
| Activity groups | A short list in `lib/data/met_table.dart`: Running, Walking and Bicycling are groups whose rows carry speed bands, each with a general entry used when no distance is given. Every other Compendium row is its own activity. The proposed general entries are open question 4. |
| Credit | About: the Compendium citation from data-sources.md (already in the About wireframe). |
| If permission has not arrived when step 5 starts | Do not guess. Options for Bart, open question 3: (a) build with the values now, since the website says the Compendium is "free to use for commercial purposes" and Phase 4 builds are only installed by Bart, and make the reply a gate for Phase 6 release; (b) build step 5 now but ship no MET table until the reply comes, so cardio shows no estimate and the user types calories; (c) hold step 5 and go on to step 6, then come back. Recommended: (a). |

## 7. Testing and the speed targets

### 7.1 Where tests run

| Kind | Runs on | What it covers |
|---|---|---|
| Unit tests (`test/`) | Local `flutter test` and CI ubuntu | Data, parser, maths, guards. |
| Widget tests (`test/screens/`, `test/speed/`) | Local and CI ubuntu | Whole screens and the whole app (`DaybookApp` with an in-memory database, a fixed clock and the real USDA asset installed in a temp folder, the same way the existing Data check test does it). Plugins mocked at the channel. |
| Integration tests (`integration_test/`) | CI only: Android emulator job and iOS simulator job (task 0.3), on pushes to main and on manual runs | The same flows on a real build: real SQLite on the device, real plugin registration, manifest and Info.plist mistakes, the widget launch link. |
| Python tests (`tools/`) | Local and CI ubuntu | The three data build scripts. |

**Time per integration test file.** Found in step 1: on the iOS simulator each file under `integration_test/` rebuilds and relaunches the app, 2 to 4 minutes per file. Tasks 2.14, 4.6, 5.4 and 8.4 add more flows. Each should add its test to one entry file that starts the app once, or the iOS job's time limits must rise again; the task that adds the fourth file decides and tests which.

**Is the emulator job worth it? Yes.** It is the only place before Bart's phones where native code runs at all: the widget launch link, Health Connect and camera permission plumbing, the notification channel, and a release build that actually starts. GitHub Actions minutes are free for public repositories, so the cost is only waiting time, which is why it runs on main and on demand rather than on every branch push. The iOS simulator job is worth it for the same reason, since there is no Mac. Neither can place a home-screen widget, scan a real barcode or read real health data.

### 7.2 The six speed targets

Taps are counted by a helper (`test/speed/tap_counter.dart`) that every flow uses: a counted tap is any `tester.tap` and any keyboard action (`testTextInput.receiveAction`). Typing with `enterText` is not counted, matching speed-targets.md. Each flow ends by checking the database.

| Target | Counted under `flutter test` | On the emulator and simulator | Only on Bart's phones |
|---|---|---|---|
| Typed 4-item meal: 1 tap, type, 1 tap | + Food, type the brief's meal, Save: 2 taps, 490 kcal stored | Same flow | Real keyboard: Save above the keyboard reachable without closing it; dictation punctuation; the parser keeping up (p95 16 ms per keystroke) |
| Saved meal or same as yesterday: 2 taps | + Food, chip: 2 taps, meal stored, Undo works | Same | That the chip row is in view on the real screen |
| Body weight under 5 s, Home or widget | Home: 2 taps plus 5 keys. Widget: launch link, then 1 tap | Same, starting the app with the widget link | The time with a stopwatch, from Home and from the widget, warm and cold. Cold start from the widget must be under about 1.5 s. Android number pad Save key; iPhone decimal pad |
| Start yesterday's or last week's routine: 1 tap | 1 tap from the Workouts tab, sets prefilled | Same | Nothing extra |
| Log a set with prefilled numbers: 1 tap | 1 tap, row completed, timer started, no permission call | Same | That no system prompt appears; vibration |
| Cardio: 1 screen | 3 taps, no second route pushed | Same | iPhone decimal pad needing the Distance tap |

### 7.3 Only on Bart's phones (Z Fold 5 and iPhone)

- Every time in seconds above, and app start from the widget.
- Parser speed on the phone: run `integration_test/parser_benchmark_test.dart` with `flutter drive` in profile mode with the phone plugged in (the Phase 4 summary gives the exact command).
- Home-screen widgets: adding them, their look at each size, refresh after a save.
- Barcode scanning of real packages in normal light.
- Health Connect and Apple Health with real data and a smart scale.
- The rest alert arriving on time with the app in the background.
- Export to a real folder or cloud drive and Import back, on both phones.
- Large text settings, folding and unfolding with text being typed, dark mode.
- First launch time (the food database unpacks once).
- The installed size from the store build.

## 8. Risks

| # | Risk | Simplest approach | How it is verified | Fallback |
|---|---|---|---|---|
| 1 | The iOS widget needs a WidgetKit extension target in the Xcode project, and there is no Mac | Write the Swift files, Info.plist and entitlements by hand. Add the target with a Ruby script that uses the `xcodeproj` gem (it comes with CocoaPods on GitHub's macOS runners), run once by a manual workflow that uploads the changed `project.pbxproj` as an artifact; commit that file. Known trap: Xcode's "Embed Foundation Extensions" phase must sit before Flutter's "Thin Binary" script phase, or the build reports a dependency cycle. | The normal iOS CI build passes and the `.appex` exists inside `Runner.app/PlugIns`. The widget itself is seen only on Bart's iPhone. | After three failed CI attempts, ship Phase 4 without the iOS widget and list it as unfinished, then add it with one rented hour on a cloud Mac. The app-side code (App Group data) stays, so nothing else changes. |
| 2 | The Android widget and Health Connect need native code and manifest entries that cannot run locally | Keep native code to the minimum: one small `AppWidgetProvider` that only displays what Dart wrote, and the health package's own native code. All logic stays in Dart, where it is tested. | CI APK build; the emulator job starts the app with the widget link; the merged permission list is compared with `tools/allowed_permissions.txt`. Health Connect with real data only on the phone. | If the health package fails on the phone, step 7 ships as unfinished; sync is optional and off by default, so nothing else depends on it. |
| 3 | HealthKit needs an entitlement and usage texts; App Group needs one too; the Phase 4 gate needs the app on the iPhone, which needs signing | Add `Runner.entitlements` (HealthKit, App Group) and the two health usage texts in step 7. The unsigned CI build ignores entitlements, so CI stays green. | CI build. The real check is the first signed install. | See open question 2: signing and TestFlight may have to move from Phase 6 into the end of Phase 4. |
| 4 | Parser speed: 16 ms per keystroke at p95 against 13,598 foods in Dart | An in-memory word index (word and joined pair to food ids) built once in the worker isolate; ranking scores only foods sharing a word; per-item result cache; typing never waits, stale results are dropped. | CI benchmark budget at half the phone target (task 2.5); phone run in profile mode (7.3). | Profile the slow part. Likely fixes: store food ids in `Int32List`s, precompute normalized descriptions in the asset build. Last resort: a short debounce (in conflict with grammar 9, so it needs Bart). |
| 5 | App size | Count it: CI prints the per-ABI APK sizes from step 0 on. Expected additions over the 26 MB per-phone build of Phase 2: zxing-cpp and CameraX, the health package (with Compose), the exercise JSON (about 1 MB before compression), the MET CSV (small). | The size line in every CI run; the summary reports the arm64 number. | If arm64 grows by more than 15 MB, the reviewer flags it to Bart. Options then: drop exercise descriptions, or compress assets as was done for the food data. |
| 6 | Widget cold start over 1.5 s | Nothing waits before the first frame: the food database install and the parser index start after it; the weight sheet needs only the user database. | Integration test checks the sheet appears without waiting for the food database; stopwatch on the phones. | A lighter first route for the widget link that shows only the weight sheet, then Home underneath once loaded (speed-targets.md already names this fix). |
| 7 | Barcode package: native builds, extra permissions | flutter_zxing builds zxing-cpp with CMake (Android) and from included sources (iOS). The camera plugin's manifest also asks for RECORD_AUDIO and old storage access: remove both in the app manifest. App Store checks may want microphone and photo library texts because the camera and image_picker code is linked even though Daybook never records sound or opens photos; those texts must say so plainly. | CI builds both platforms; permission allow list; first TestFlight upload. | zxing2 (pure Dart) with the camera package. |
| 8 | Rest alert while the app is in the background on Android | Schedule the notification with Android's inexact mode, which needs no extra permission. | Phone check: rest of 60 and 90 s with the phone locked. | Open question 6. |
| 9 | Installs of the Phase 2 build have the old version 1 database | Bart uninstalls the Phase 2 build first (amended v1 decision). | Stated in the Phase 4 summary. | Version 2 with a migration (open question 1, option b). |
| 10 | MET values copied wrongly from the PDF (the terms forbid changing them) | Script plus committed CSV; spot checks in tests; the reviewer compares 30 random rows with the PDF. | Task 5.1 tests and review. | Correct by hand and record each correction in `assets/met/README.txt`. |
| 11 | Isolates do not run inside widget test fake time | Inline mode in the parse worker (2.7 of the architecture). | Widget and speed tests use it; the worker's own test uses a real isolate. | None needed. |
| 12 | Step 2 is large | Fourteen small tasks with tests first; the 88 examples written by the Test agent, not the parser author. | CI per task. | Report slippage in the step summary, do not cut grammar rules silently. |
| 13 | Android minSdk rises from Flutter's default to 26 (Android 8.0) because the health package needs it | Accept: phones older than Android 8 are a very small share. | Build config. | None; noted in the summary. |

## 9. Open questions for Bart

Recommendation first in each.

1. **Schema change: amend version 1 or add version 2?** (needed before task 0.1)
   - (a) **Recommended:** amend version 1, since nothing is released. Uninstall the Phase 2 build from your phone first. Section 3.1 says why and how CI still passes.
   - (b) Version 2 with a migration, as the Phase 3 summary worded it. Also needs code to import version 1 backup files into version 2. More code and tests for no user.
2. **Installing on the iPhone for the Phase 4 gate.** An iPhone install needs a signed build (Apple Developer account, certificates, App IDs for the app and the widget, the App Group and the HealthKit capability). PHASES.md puts signing and TestFlight in Phase 6.
   - (a) **Recommended:** move the TestFlight setup into the end of Phase 4: an agent adds the signing steps to CI, you do the account and portal steps by hand. Then the gate can be checked as PHASES.md says.
   - (b) Keep signing in Phase 6. The Phase 4 gate is the Android phone plus the iOS simulator run in CI; the iPhone check moves to Phase 6.
3. **Compendium permission not yet received when step 5 starts.**
   - (a) **Recommended:** build with the values now (the site says free for commercial use; Phase 4 builds are only on your phones) and make the reply, or your decision to go ahead without one, a gate for Phase 6.
   - (b) Build step 5 without the MET table; cardio has no estimate until the reply.
   - (c) Pause step 5, do step 6, come back.
4. **Cardio groups with speed bands, and the entry used when no distance is typed.**
   - (a) **Recommended:** Running (rows 12028 to 12135 by mph; general entry 12145 "Running, self-selected pace", 10.5); Walking (the level, firm surface rows 17151 to 17230; general 17190 "Walking, 2.8 to 3.4 mph, level, moderate pace", 3.8); Bicycling (the mph rows; general 01014 "Bicycling, general", 7.0). Every other row is its own activity.
   - (b) Use 12020 "Jogging, general, self-selected pace" (7.5) as Running's general entry, which gives lower estimates.
5. **Workouts imported from Health Connect or Apple Health.**
   - (a) **Recommended:** import every exercise session as a cardio session. Calories: the platform's total if it gives one, otherwise a MET estimate where the type maps to a Compendium row, otherwise empty. The user can change or delete any of them. Risk: a strength session logged in both Daybook and another app is counted twice; deleting one fixes it.
   - (b) Import only cardio-type sessions (running, walking, cycling, swimming and so on), never strength training.
6. **Rest alert timing on Android.**
   - (a) **Recommended:** inexact scheduling, no extra permission. It may arrive some seconds late; check it on your phone.
   - (b) Ask for the exact alarm permission too. On Android 14 and later that is a trip to a system settings page, a second prompt after the notification one.
7. **The "Some illustrations by Everkinetic" sentence in About.** Shipping wger images was never designed (no frame shows one), and they would add size and per-image credits.
   - (a) **Recommended:** ship no images and drop that one sentence from the About credit; the rest stays word for word.
   - (b) Ship the images and keep the sentence.
8. **Items the Phase 3 summary listed as missing from the brief** ("listed, not drawn"; your approval did not cover them because no recommendation was made).
   - (a) **Recommended:** add only a one-line "Daybook collects no data" statement in About, since it restates a promise. Leave first-run setup (Home's "Set your goals" card covers it), hiding the weight on the widget, a weight typo check and calorie quick-add for the Phase 5 friction log.
   - (b) Build some or all of them now (each needs a design first).

## 10. Task count

| Step | Tasks | Data/Nutrition | UI | Test | Lead |
|---|---|---|---|---|---|
| 0 Changes to Phase 2 work | 3 | 2 | 0 | 1 | 0 |
| 1 Weight and widget | 6 | 1 | 4 | 1 | 0 |
| 2 Food | 14 | 6 | 6 | 2 | 0 |
| 3 Goals and budget | 3 | 1 | 1 | 1 | 0 |
| 4 Resistance training | 6 | 2 | 3 | 1 | 0 |
| 5 Cardio | 4 | 2 | 1 | 1 | 0 |
| 6 Summaries | 3 | 1 | 1 | 1 | 0 |
| 7 Health sync | 2 | 1 | 1 | 0 | 0 |
| 8 About, settings, units | 5 | 1 | 2 | 1 | 1 |
| **Total** | **46** | **17** | **19** | **9** | **1** |
