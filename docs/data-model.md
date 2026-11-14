# Data model

Daybook keeps two SQLite databases on the phone.

| Database | What it holds | Who writes it | Updated by |
|---|---|---|---|
| User database (`daybook.sqlite`) | Everything the user logs or creates | The app | Schema migrations |
| Food reference (`usda.sqlite`) | USDA foods, nutrients, portions | `tools/build_food_db.py` at build time | Replaced whole when a new app version ships newer data |

Keeping them apart means:
- a USDA data update never needs a migration of user data;
- export only has to cover the user database;
- the reference file can be read-only.

The user database is defined in `lib/data/database.dart` (drift). The reference database is described in [Food data shipping](#food-data-shipping) below.

## Conventions

- **Days** are stored as text, `YYYY-MM-DD`, in the user's local time when the record was made. The day is saved, never recomputed from a timestamp. A weigh-in at 7:00 in Tokyo stays on that day after flying home. This is what makes the time zone and date boundary tests possible.
- **Instants** are integer milliseconds since the epoch (UTC). The local offset in minutes is stored next to them.
- **Units** are stored in metric: kilograms, meters, grams or milliliters. Pounds and inches are a display setting only. 180.4 lb is stored as 81.82806 kg (1 lb = 0.45359237 kg exactly) and shown again as 180.4 lb.
- **Nutrient ids** are USDA FoodData Central nutrient ids everywhere, for example 1008 energy and 1003 protein. The tracked list is in `lib/data/nutrients.dart`. Open Food Facts values are mapped onto the same ids.
- **Food references** are text:
  - `usda:<fdc id>` for the reference database;
  - `local:<id>` for the `foods` table (user foods, recipes, cached Open Food Facts products).
  - Exercises follow the same pattern: `wger:<id>` for the library, `local:<id>` for user exercises.
- **Logged items keep a copy** of the food or exercise name and the nutrients. Editing a food, updating USDA data, or deleting a food never changes past days. The same idea comes from Waistline's archive-don't-delete (survey.md).
- **Archive instead of delete** for things that past records point to: foods, meal slots, exercises, routines.

## Tables (schema version 1)

Version 1 was amended before any release (`goals.fixed_calories` became `calories`, and `meals.saved_meal_id` was added), so there is no migration for it. The next schema change is version 2, with a migration.

### Food

| Table | Purpose | Key columns |
|---|---|---|
| `foods` | User foods, recipes, cached Open Food Facts products | `kind` ('custom', 'recipe', 'off'); `barcode` (unique); nutrients are per `base_amount` of `base_unit` ('g', 'ml' or 'serving') |
| `food_nutrients` | Nutrients of a local food | (`food_id`, `nutrient_id`), `amount` per base amount |
| `food_portions` | Household portions, for example "slice" = 30 g | `food_id`, `label`, `base_quantity` |
| `recipe_ingredients` | What a recipe is made of | `recipe_food_id`, `food_ref`, `quantity`, `unit_label`, `base_quantity`. The recipe's totals are stored in `food_nutrients` when it is saved. |
| `meal_slots` | Breakfast, Lunch, Dinner, Snack; user can rename, add, reorder | `name`, `position`, `archived` |
| `meal_slot_rules` | Default slot by time of day | `start_minute` (0 to 1439), `slot_id`. A rule applies until the next rule starts. |
| `meals` | One save from the food entry screen | `local_date`, `slot_id`, `logged_at_ms`, `source_text` (what was typed), `saved_meal_id` (nullable; the first saved meal expanded in this meal, set to null if that saved meal is deleted) |
| `meal_entries` | One line of a meal | `food_ref`, `food_name`, `quantity` and `unit_label` as entered ("2 slice"), `base_quantity` and `base_unit` (60 g) |
| `meal_entry_nutrients` | Nutrients for the amount eaten | (`entry_id`, `nutrient_id`), `amount` |
| `saved_meals`, `saved_meal_items`, `saved_meal_item_nutrients` | Saved meals, same shape as meals | |
| `aliases` | "usual breakfast" expands to a saved meal | `phrase` (unique), `saved_meal_id`. The phrase is stored as the user typed it, trimmed, and compared through `nameKey` (`lib/parser/name_key.dart`) when it is used or checked for a clash, so a later change to the comparison rules cannot orphan saved aliases. |
| `learned_matches` | Corrections the parser learns: "toast" means this bread | `phrase` (key), `food_ref`, last `unit_label` and `quantity`, `times_used` |

Default meal slots and rules come from the brief:
- Breakfast until 10:30
- Lunch 10:30 to 2:30
- Snack 2:30 to 5:00
- Dinner 5:00 to 9:00
- Snack after 9:00

They are inserted when the database is created.

### Body weight

| Table | Purpose | Key columns |
|---|---|---|
| `weight_entries` | Weigh-ins | `local_date`, `measured_at_ms`, `tz_offset_minutes`, `weight_kg`, `source` ('manual', 'health_connect', 'apple_health'), `source_id`, `deleted_at_ms` |

- More than one entry per day is allowed. The trend line decides how to use them.
- (`source`, `source_id`) is unique, so a health sync can never import the same weigh-in twice.
- Deleting sets `deleted_at_ms` instead of removing the row, so a later health sync cannot bring a deleted weigh-in back. Screens, totals and the trend skip deleted rows. `cardio_sessions` works the same way, because workouts can be imported from Health Connect and Apple Health.

### Training

| Table | Purpose | Key columns |
|---|---|---|
| `exercises` | Exercises the user creates | `name`, `category`, `primary_muscles`, `secondary_muscles` (comma separated), `equipment` |
| `routines` | Templates | `name`, `position`, `archived` |
| `routine_exercises` | Exercises in a routine | `exercise_ref`, `exercise_name`, `target_sets`, `rest_seconds` |
| `workouts` | One session | `local_date`, `started_at_ms`, `ended_at_ms`, `routine_id`, `kcal_estimated`, `kcal_override` |
| `workout_sets` | Sets in a session | `exercise_ref`, `exercise_name`, `weight_kg` (null for body weight), `reps`, `completed_at_ms` (null until done) |
| `cardio_sessions` | Cardio | `activity_code` (Compendium code), `activity_name`, `met`, `duration_seconds`, `distance_meters`, `avg_heart_rate`, `kcal_estimated`, `kcal_override`, `source`, `source_id`, `deleted_at_ms` |

- Prefilled sets: a new workout from a routine copies the last session's `weight_kg` and `reps` for each exercise. That is a query on `workout_sets`, not a stored copy.
- The wger exercise library ships as a JSON asset (assets/exercises/wger_exercises.json) and is read into memory by lib/data/exercise_library.dart, added in Phase 4. It is not in either database. The user database holds the user's own exercises, routines, workouts and sets.

### Goals and settings

| Table | Purpose | Key columns |
|---|---|---|
| `profile` | One row: inputs for Mifflin-St Jeor | `sex`, `birth_date`, `height_cm` |
| `goals` | Calorie and macro goals, versioned by date | `effective_from` (unique), `calorie_mode` ('calculated' or 'fixed'), `calories` (the calorie goal in both modes: the calculated number stored when Goals is saved, or the number the user typed), `activity_factor`, `target_kg_per_week`, `exercise_add_back_percent` (0, 50, 100; default 100), `macro_mode` ('grams' or 'percent'), protein, carbs and fat targets |
| `goal_nutrients` | Other nutrient targets | (`goal_id`, `nutrient_id`), `target_amount` |
| `settings` | Small key and value settings | `units` = 'imperial' by default |

A day is compared with the goal row that has the latest `effective_from` on or before that day. Changing goals does not rewrite how past days looked.

Body weight for the calorie math comes from `weight_entries`, not from `profile`.

## Migrations

- `AppDatabase.schemaVersion` is 1. Each future schema change:
  1. raises the version;
  2. adds a step in `onUpgrade`;
  3. is snapshotted with `dart run drift_dev make-migrations`. That writes `drift_schemas/default/drift_schema_vN.json` and generates migration tests under `test/drift/`.
- CI runs `make-migrations` and fails if the schema files change. A schema edit without a new version and a committed snapshot cannot be merged.
- Foreign keys are on (`PRAGMA foreign_keys = ON` before open).

## Export and import

- Export writes one `.zip` file containing:
  - `daybook.json`: every table, every row, every column, plus the schema version;
  - `csv/<table>.csv`: one file per table, for spreadsheets;
  - `README.txt`: what the files are, and the Open Food Facts ODbL notice for cached products.
- Import reads `daybook.json` and **replaces** all user data. The whole file is checked first. Then everything is written in one transaction, so a bad file changes nothing.
- A file from a newer schema version is refused.
- Code: `lib/data/export_import.dart`. Tests: `test/data/export_import_test.dart`.

The brief says "Export everything to a single file (JSON and CSV)". There were two readings:
- (a) one file that contains both JSON and CSV;
- (b) the user picks JSON or CSV.

We chose (a). The zip is one file, the JSON gives a lossless restore, and the CSVs open in a spreadsheet. Import reads the JSON only.

## Food data shipping

**Decision: bundle the USDA data in the app.** No download.

What ships:
- `assets/food/usda.sqlite.gz`: 7.1 MB. Uncompressed it is 20.0 MB.
- 13,598 foods:
  - SR Legacy: 7,793
  - FNDDS 2021-2023: 5,431
  - Foundation Foods 10/2026: 374
- Every nutrient USDA gives, and 36,444 household portions. That includes 5,362 FNDDS rows labelled "Quantity not specified", kept as the default amount for a food typed with no amount.
- It is built by `tools/build_food_db.py` from pinned USDA files, and the script checks their SHA-256.

| Option | App download | First run | Works offline at once | Network calls |
|---|---|---|---|---|
| Bundle (chosen) | +7.1 MB (+4.7 MB without FNDDS) | Unzips 20.0 MB to app storage, about 0.1 s on a PC; on a phone it is expected to stay well under a second (not measured on a phone yet) | Yes | None |
| Download on first run | +0 | Needs a connection; food logging waits for the download | No | One more host to call and to host the file on |
| Both | +7.1 MB | Same as bundle | Yes | Optional update call |

Why bundle:
- the app works the moment it is installed, even with no signal;
- there is no extra network call (the promise allows one, but none is better);
- there is no file to host;
- updates arrive with app updates, about twice a year when USDA releases.

The cost is 7.1 MB on the download, plus 20.0 MB on the phone once installed.

Why include FNDDS (+2.4 MB):
- it has foods as people eat them: mixed dishes, prepared foods, more "toast" and "oatmeal" variants;
- free-text entry matches better against those than against raw ingredients.

Building it:
- Foods with no energy value at all are skipped (50 unfinished Foundation entries, 1 FNDDS entry). SR Legacy still covers those foods.
- FNDDS portions: "Guideline amount per ..." rows are survey coding aids and are skipped. "Quantity not specified" is kept with its label, in its FNDDS position. The app never lists it as a choice and uses it only as the default amount.
- The build fills a few standard nutrient ids from close equivalents, so the app reads one id per nutrient. The rules are also stored in the database's `meta` table:

  | Nutrient | Filled from, in order |
  |---|---|
  | Energy 1008 | Atwater specific 2048, then Atwater general 2047, then kJ 1062 / 4.184 |
  | Fat 1004 | NLEA fat 1085 |
  | Carbs 1005 | carbs by summation 1050 |
  | Sugar 2000 | NLEA sugars 1063 |
  | Folate DFE 1190 | total folate 1177, but only when folic acid 1186 is listed as 0. DFE counts folic acid 1.7 times, so for enriched foods it is left "not listed" rather than shown too low. |

- The October 2026 Foundation Foods CSV download is missing its food tables, so the build reads the Foundation JSON file instead.

Installing it:
- On first launch, and after an app update with a new data version, the app unzips the asset to a temporary file and renames it into place, so a crash cannot leave half a file.
- `assets/food/usda_version.txt` holds the data version: the USDA release plus a checksum of the database (for example `2026-10-29-5000bc2f130d000`). Any rebuild changes it, so a fixed asset always reaches existing installs.
- If the installed file is missing or does not open as a food database, the app installs it again.

Reference database tables:
- `meta`
- `nutrient` (id, name, unit)
- `food` (id = FDC id, dataset, description, category)
- `food_nutrient` (per 100 g)
- `food_portion` (label, grams)

Open Food Facts products are not bundled. They are fetched only when the user scans a barcode, then cached in the user database (`foods` with kind 'off').
