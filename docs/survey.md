# Phase 1 survey

Researched 2026-11-08. Public information only. Licenses were read from the actual LICENSE files. Anything not confirmed is marked **unverified**. Data source licenses are in [data-sources.md](data-sources.md).

## 1. Existing open-source trackers

### At a glance

| App | License | Stack | Platforms | Food | Lifting | Weight | Last active |
|---|---|---|---|---|---|---|---|
| OpenNutriTracker | GPL-3.0 | Flutter | Android, iOS | Yes | No (imports workouts) | Unverified | 2026-10-30 (v2.6.0) |
| Waistline | GPL-3.0-or-later | Cordova (JS) | Android | Yes | No | Yes | 2026-10-21 |
| wger | AGPL-3.0 | Flutter app + Django server | Android, iOS, Linux | Yes | Yes | Yes | 2026-11-08 |
| Energize | AGPL-3.0-only | Flutter | Android (F-Droid), web | Yes | No | Not found | 2026-10-26 |
| Flex (was Flexify) | MIT | Flutter | Android, Windows | No | Yes | Yes | 2026-11-07 |
| Liftosaur | AGPL-3.0 | Preact PWA with app wrappers | Android, iOS, web | No | Yes | Yes | 2026-11-02 |
| FitoTrack | GPL-3.0-or-later | Native Android | Android | No | No (GPS cardio) | No | 2026-10-15 |

Also checked: Massive (GPL-3.0, archived 2025, the predecessor of Flex), LibreFit by LibreFitOrg (GPL-3.0, Android workouts only), LibreFit by thwbh (GPL-3.0, small, uses an LLM for photo estimates).

### OpenNutriTracker

- Repo: https://github.com/simonoppowa/OpenNutriTracker
- License: GPL-3.0 (the LICENSE file is GPL v3; no source headers, so "only" vs "or later" is unclear).
- Stack: Flutter, flutter_bloc, encrypted Hive storage. On Google Play and the App Store.
- Food data: Open Food Facts, USDA FDC and the German BLS, served through the project's own Supabase backend.

**Important finding: it already does free-text, multi-item meal entry.** Version 2.2.0 (released 2026-09-01) added "AI-assisted meal logging" with a deterministic, on-device text parser (PR #616, verified). The parser:
- splits on commas, semicolons, plus signs and newlines, and treats a comma between two digits as a decimal point;
- reads a quantity and a metric unit (g, kg, ml, l, oz, fl oz) before or after the food name, and a bare number as a count;
- leaves household words like "slice" or "tbsp" in the search text and matches them against the food's own portion labels, so "2 tbsp" never becomes "2 g";
- sends every parsed line to a review screen where the user can re-match, edit or skip each line before saving;
- does not handle number words ("two eggs").

An optional bring-your-own-key AI model can also interpret the text, but nutrition numbers always come from the databases. The parse runs on the device, but **the match for each line is an online search** against their backend, so the full flow needs a network.

What it does well:
- No account, no ads.
- Barcode, quick add, meals and recipes.
- Micronutrient day and week views.
- Documented JSON and CSV export.
- Health Connect and Apple Health workout import, off by default.

Conflicts with Daybook's promises:
- Opt-in Sentry crash reporting.
- Food search goes to a backend that logs IP addresses for 24 hours.

Where entry is slow:
- Issue #458 (2026-05-23) counts 7 taps to add one item: the add button, the meal, the source, the product, the unit, the quantity, and Add.
- Related requests ask for:
  - remembering the last quantity (#1265);
  - quick multiplier chips (#577);
  - plus or minus one serving without opening a dialog (#1300);
  - recent foods by default instead of behind a tab (#1130).
- Tap counts for the new text flow and for weight entry: **unverified**.

### Waistline

- Repo: https://github.com/davidhealey/waistline
- License: GPL-3.0-or-later (file at `www/LICENSE.txt`).
- Stack: Cordova and Framework7. Android only (F-Droid, Google Play).
- Food data: Open Food Facts. USDA only with the user's own API key.

What it does well:
- A mature diary with custom meal categories.
- "Meals" that expand into separate entries, as opposed to recipes, which log as one entry.
- Multi-select add from the food list.
- Long-press quick add of calories.
- Exercise logged as negative calories.
- Old foods are archived instead of deleted, so past diary entries keep their numbers.

Where entry is slow:
- A food must already be in the local list, or be found by an online search that only runs when you press Enter.
- Small checkbox targets: a miss opens the editor (#439).
- Slow transitions (#618).
- Search clears when you switch tabs (#411).
- USDA needs a personal API key (#799).
- Open Food Facts text search times out (#909, #956).

### wger

- Repos: https://github.com/wger-project/flutter and https://github.com/wger-project/wger
- License: AGPL-3.0 for both. Exercise data is under separate Creative Commons licenses (see data-sources.md).
- Needs an account on wger.de or a self-hosted server. Without a server the app is not usable (#917).

What it does well:
- Nutrition, routines, body weight and measurements in one app.
- A large shared exercise database.
- Health Connect and Apple Health sync.

Where entry is slow or fragile:
- Each set takes a swipe and then a confirm. Users ask for a prefilled checklist where one tap logs a set (#1304).
- Several sync and data-loss reports (#1371, #1265, #1352, #1361). This is a lesson for Daybook: dependence on a server is the top source of complaints.

### Energize

- Repo: https://codeberg.org/epinez/Energize
- License: AGPL-3.0-only.
- Flutter. F-Droid, IzzyOnDroid and a web build. iOS **unverified**.
- Food data: Open Food Facts, USDA, the Swiss food database, and custom foods.

What it does well:
- Micronutrients.
- Databases you can switch on and off.
- Barcode lookup checks custom foods first.
- Recent-food suggestions.
- Optional automatic grouping into meals.
- Encrypted backup.

Where entry is slow:
- About 5 taps plus 2 typed fields per item.
- Search is not as-you-type (#163, a complaint).
- No copying of foods between days (#108).

### Flex (formerly Flexify)

- Repo: https://github.com/brandonp2412/Flex
- License: MIT.
- Flutter, local database, no account. F-Droid and Google Play. iOS **unverified**.

What it does well:
- Reps and weight are prefilled from the previous set, and a single Save button logs it. A repeat set is 1 tap after the exercise is open.
- The rest timer starts on save.
- The keyboard Enter key also saves.
- Body-weight page, graphs, import and export.

Where entry is slow: nothing notable found. Tap count from the home screen to the first set is **unverified**.

### Liftosaur

- Repo: https://github.com/astashov/liftosaur
- License: AGPL-3.0.
- Web app wrapped for Android and iOS. Optional cloud account. Uses Rollbar error reporting.
- A third-party review says some features are paid; not confirmed on an official page.

What it does well:
- Prefilled sets checked off with one tap, which starts the rest timer.
- Last results shown for similar sets.
- Weights rounded to the plates you own.
- A small scripting language for progression rules.

### FitoTrack

- Repo: https://codeberg.org/jannis/FitoTrack
- License: GPL-3.0-or-later. Native Android, GPS recording of runs, rides and hikes.
- Not a quick logger and has no MET estimates. Included only for cardio summary ideas.

### Ideas worth borrowing (ideas, not code)

Food entry:
- Parse, then review, then save as one batch. Check every line before any write, so a meal saves fully or not at all.
- Never turn an unknown unit into grams. Keep it as a count and let the user fix it.
- Match household units ("slice", "cup") against the food's own portion sizes rather than a fixed table.
- Show unmatched lines clearly and never drop them silently. Flag weak matches below a score threshold.
- Remember the last quantity and unit per food.
- Quick multiplier chips (half, 1x, 2x).
- Recents shown by default, not behind a tab.
- As-you-type search.
- Save with the keyboard Enter key.
- Meals that expand into separate entries.
- Archive foods instead of deleting them, so old diary entries keep their values.

Lifting:
- Prefill sets from last time, 1 tap to confirm.
- The rest timer starts on confirm.
- Show last results next to each set.
- Plate-aware rounding (later, not v1).

General:
- Large tap targets.
- No server dependency.
- Exercise calories raise the day's budget.

### How Daybook differs

OpenNutriTracker is the closest project: same stack, same license, and it now has text entry. Daybook can still be meaningfully better on the brief's own terms:

1. **Fully offline match.** Daybook parses and matches against an on-device food database plus the user's history, so entry works on a plane and sends nothing.
2. **Household units and number words** handled by the parser ("2 slices", "1 tbsp", "two eggs", "half a cup").
3. **No separate review screen.** Parsed lines appear live under the text box on the same screen, and Save is one tap.
4. **Learning from corrections and aliases** ("usual breakfast").
5. **Lifting, cardio and weight in the same app**, with no account and no crash reporting.

If Daybook ever wanted to reuse code, the GPL-3.0 and MIT projects (OpenNutriTracker, Waistline, Flex, FitoTrack) are compatible with the Daybook license, with attribution. AGPL projects (wger, Energize, Liftosaur) are ideas only. The plan for now is ideas only.

---

## 2. MyFitnessPal feature inventory

From public sources only: MFP help center articles, the MFP blog, app store listings, press releases, reviews and forum posts. MFP's help center blocks automated reads, so the details below come from search summaries of those pages. Treat exact tier placement as **likely but not hand-checked**. Everything is in our own words.

Tiers: Free; Premium (about $79.99 a year); Premium+ (about $99.99 a year, adds a meal planner, sold in a few countries).

Since late 2025, the old Diary is replaced by a "Today" tab of cards. A second wave of changes came in April 2026. Users cannot go back to the old layout.

| Area | Feature | Tier |
|---|---|---|
| Food | Text search of a large, mostly user-submitted database | Free |
| Food | Barcode scan | Premium (since Oct 2022) |
| Food | Meal Scan (camera AI) | Premium |
| Food | Voice log: one sentence becomes several entries; English only, online, no custom foods or saved meals | Premium |
| Food | Quick add, calories only | Free |
| Food | Quick add with macros | Premium |
| Food | Copy a meal to another day (meal level only) | Free |
| Food | Saved meals, custom foods, manual recipe builder | Free |
| Food | Recipe import from a URL | Reportedly moved to Premium in 2026 (unverified) |
| Food | Food timestamps | Premium |
| Nutrients | Calories, protein, carbs, fiber, sugar, total fat, saturated, mono and poly fat, trans fat, cholesterol, sodium, potassium, vitamin A, vitamin C, calcium, iron | Free to view |
| Nutrients | Nutrient dashboard presets, net carbs mode, macro goals per meal, gram views on Today | Premium |
| Goals | Calorie goal from Mifflin-St Jeor times activity, adjusted for weekly rate; custom calorie goal | Free |
| Goals | Macro goals in percent (5% steps) | Free |
| Goals | Macro goals in grams | Premium |
| Goals | Different goals by day of week | Premium |
| Goals | Exercise calories added back: always on | Free |
| Goals | Turning add-back off | Premium |
| Goals | Step and tracker "calorie adjustment" | Free |
| Weight | Weight log, one value per day | Free |
| Weight | Extra measurements (added on website only); edit past entries on website | Free |
| Weight | Progress photos, smart scale sync | Free |
| Exercise | Cardio from a list with an estimated burn | Free |
| Exercise | Strength entry: sets, reps and one weight for the whole entry; zero calories | Free |
| Exercise | Workout routines with per-set weight and reps | Unclear (sources disagree) |
| Exercise | Custom exercises | Free |
| Devices | Health Connect, Apple Health, Garmin, Fitbit/Google Health, Samsung Health, 40+ partners, Apple Watch and Wear OS apps, home-screen widget | Free to link |
| Other | Water, daily food and exercise notes, meal reminders, streaks, printable diary report (website) | Free |
| Other | Weekly digest | Free (last 2) / Premium (all) |
| Other | Intermittent fasting timer | Premium |
| Other | Friends, forums, groups, diary sharing | Free |
| Other | AI coach, GLP-1 logging | Unverified |
| Other | No ads, data export | Premium |

Nutrients MFP does not appear to track, but the Daybook brief requires (no official full list was found, so **unverified**):
- added sugar
- magnesium
- zinc
- vitamins D, E, K, B6 and B12
- folate

MFP may store vitamin A, vitamin C, calcium and iron as percent of Daily Value rather than mg or mcg (older help material; possibly outdated).

### Public complaints that match the brief's three problems

1. **Entry takes too many screens.**
   - After the Today redesign, users report more taps for routine logging, a hidden full diary ("View All"), harder-to-find meal macros, and lag.
   - No measured tap counts were found.
   - Sources: piunikaweb.com (April 2026), consumerrights.wiki.
2. **Strength is an afterthought.**
   - The plain strength entry takes one weight for all sets and gives zero calories, so users also log "strength training" as cardio minutes.
   - Common gym exercises are missing.
   - Sources: MFP community threads 10543108, 1041944, 10442839.
3. **Weight entries are unreliable.**
   - There is no single canonical bug, but there is a steady pattern:
     - weight history shown in reverse order and older entries missing on Android (Sept to Oct 2025);
     - entries gone after updates but still visible on the website;
     - iOS release notes fixing the "Weight logged!" confirmation and a missing add-weight button;
     - goals reverting on Android.
   - Sources: MFP community threads 48779155, 10032543, 10022813, 10942695; the App Store release notes.

Paywall creep comes up often too: barcode scan (2022), and reportedly Meal Scan, recipe import and per-meal macros (2026). Daybook gives all of these for free except camera AI and voice parsing, which are out of scope. Note that phone keyboards offer dictation, which covers "types or dictates" in the brief.

---

## 3. MyFitnessPal data export

### What exists

**Premium export (Premium and Premium+ only).**
- Requested in the app or on the website (Reports, then Export).
- The user picks a date range. An email arrives with a link to a ZIP.
- The ZIP holds three CSV files:
  - **Nutrition:** calories, macros and micronutrients, **summed per meal per day** (Breakfast, Lunch, Dinner, Snacks), plus food notes. If foods in one meal had different timestamps, each time gets its own row. **No individual foods.** MFP staff and several user threads confirm there is no per-food export.
  - **Progress / measurements:** weight and other body measurements by date.
  - **Exercise:** exercise history. Columns not verified. Older tools reported minutes, calories, sets, reps and weight.
- Not included, as far as the official description goes: custom foods, recipes, saved meals, goals, water, photos.
- File names have changed over the years (for example "Nutrition Summary" in 2016, possibly "Your Nutrition" now). **Exact current headers, date format and units are not verified.**

**Free tier.** No CSV export. Options:
- A printable diary report on the website (Food Diary, Exercise Diary, Notes), saved as HTML or PDF. It probably lists individual foods (unverified). An open-source parser exists, last tested in 2019.
- A privacy or data-portability request (GDPR and some US states). One commercial blog says this returns a password-protected spreadsheet with per-food rows. **Single source, unverified**, and may depend on region.

**Health Connect / Apple Health.** If the user linked MFP, it wrote per-meal nutrition summaries and weight from the day they linked onward. With the user's permission, Daybook's optional health sync could read those back. How far back Health Connect lets an app read is **unverified**.

### Is import possible?

Yes, with limits. From the Premium CSV export, Daybook could import:
1. **Weight and body measurements.** High value, simple.
2. **Meal totals per day** as "imported meal total" entries (calories, macros, micronutrients by meal).
3. **Exercise entries:** at least name, minutes and calories.

What would be lost:
- Individual foods and amounts.
- Custom foods, recipes and saved meals (the user rebuilds favorites).
- Goal history, water and photos.
- Probably per-set strength detail.
- Exact units for vitamin A, vitamin C, calcium and iron if they are percent of Daily Value.

Decision (Bart, 2026-11-08): **skip MyFitnessPal import for now.** It stays out of Phases 2 to 4 and gets listed as not done in the Phase 4 summary. The notes below are for whenever it comes back.

Recommendation if it comes back:
- Treat MFP import as **weight first, then meal totals, then exercise**.
- Match columns by header name, not by position or file name, and ask the user which weight unit the file uses.
- Do not design the importer until we have a real Premium export to look at (see the open questions in the Phase 1 summary).

Sources for this section include:
- MFP help center articles 360032273352 and 360032623371 (export)
- MFP blog "take fitness info beyond app new feature" (2016)
- MFP community threads 10957736 and 10855171
- https://github.com/YoussefSultan/myFitnesspalDataConverter
- https://foodzilla.helpscoutdocs.com/article/203-how-do-i-import-a-myfitnesspal-food-diary-into-foodzilla
- https://github.com/leaherb/myfitnesspal-diary-parser
- https://nutriscan.app/blog/posts/how-to-export-myfitnesspal-data-661c26d333
- https://forkmate.ai/blog/export-myfitnesspal-data-free/ (unverified claim)
