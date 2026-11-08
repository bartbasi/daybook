# Daybook: Product Brief

Working title. The name can change later; keep it in one constant and one strings file so a rename is cheap.

Owner: Bart Basi, Play, Inc.
Package: `io.github.bartbasi.daybook`
Repo: github.com/bartbasi/daybook

## What this is

A free, open-source tracker for food, macros, micronutrients, body weight, resistance training and cardio. It replaces MyFitnessPal for people who like what MFP tracks but not how it works. The whole point is speed of entry.

## Promises (non-negotiable)

- Free forever. No ads, no upsells, no premium tier, no locked features.
- Collects no data. No accounts, no analytics, no crash reporting services, no network calls except food database lookups and the optional health platform sync the user turns on.
- All user data stays on the device. Export and import to a file the user controls.
- Open source under the same license and attribution terms as the other Play, Inc. apps (copy LICENSE and attribution wording from the WoodLogic repo verbatim).
- Only revenue: a Buy Me a Coffee link (buymeacoffee.com/playinc), "appreciated but never expected." One row in About, never a popup.

## Platforms

- Flutter. Android and iOS released to both stores as close together as possible.
- Android first for development, iOS following within days, not months.
- No Mac on hand: iOS builds and TestFlight uploads run on a cloud macOS runner (GitHub Actions or Codemagic). Real-device testing on one Android phone and one iPhone.
- Portrait first; must not break on foldables (owner uses a Samsung Z Fold 5).

## The three problems this app exists to fix

1. **Meal entry takes too many screens.** MFP makes you add each ingredient separately.
2. **Resistance training is an afterthought.** No good way to log sets, reps and weight.
3. **Weight tracking is unreliable.** Entries often fail to save.

## Core features, version 1

### Food: one-screen entry

- Home screen has a Food button. One tap opens the entry screen. Nothing in between.
- Top of the screen: date (default today) and meal (default from the clock, see below). Both changeable with one tap.
- Below: one free-text box. The user types or dictates the whole meal, for example:
  `2 eggs, 2 slices sourdough toast, 1 tbsp butter, coffee with 2 tbsp half and half`
- As the user types, the app parses the text into lines under the box. Each line shows food, amount, calories and protein/carbs/fat. Tap a line to change the match or amount.
- Save button saves the whole meal. One screen, start to finish.
- Parsing is fully on-device (no AI model, no cloud). Rule-based quantity/unit parsing plus fuzzy matching against the food database and the user's own history.
- The app learns from corrections. If the user fixes "toast" to a specific bread once, that becomes the default match next time.
- Saved meals and aliases: typing `usual breakfast` or `my oatmeal` expands to the saved items.
- Also on the same screen: recents and frequents for this meal slot, and "same as yesterday."
- Barcode scan as a secondary input that adds a line to the current meal.
- Default meal by time (user-adjustable): Breakfast until 10:30, Lunch 10:30 to 2:30, Snack 2:30 to 5:00, Dinner 5:00 to 9:00, Snack after 9:00.
- Meal slots are user-editable (rename, add, reorder).

### Nutrition data

- Sources: USDA FoodData Central (public domain) as the base, Open Food Facts for barcodes and packaged foods (ODbL; keep its data and attribution separate from app code).
- User-created foods and recipes, stored locally.
- Track calories, protein, carbs, fat, fiber, sugar, added sugar, saturated fat, trans fat, cholesterol, sodium, potassium, calcium, iron, magnesium, zinc, vitamins A, C, D, E, K, B6, B12, folate. Store whatever else the source provides so more can be shown later.
- Daily and weekly views: totals against goals, and which foods contributed most to each nutrient.

### Body weight

- Reliability is the requirement. Writes go to the local database immediately and are confirmed on screen. Automated tests cover entry, edit, delete, unit switching, time zone changes and date boundaries.
- Entry from the home screen in under 5 seconds, plus a home-screen widget.
- Trend line that smooths daily noise.
- Optional sync from Health Connect (Android) and Apple Health (iOS) so smart scales work. Off by default.

### Resistance training

- Exercise library (open-licensed list, license verified in Phase 1) plus user-created exercises.
- Routines (templates). Start a routine and every set is prefilled with last session's weight and reps; the user confirms or adjusts.
- Rest timer, personal records, estimated 1-rep max, weekly volume per muscle group.
- Repeat a previous workout in one tap.

### Cardio

- Log activity, duration, and optional distance and heart rate.
- Calorie burn estimated from MET values, body weight and duration. Show the estimate and let the user override it.
- Optional import of workouts from Health Connect / Apple Health.

### Daily calorie budget

- Base goal from Mifflin-St Jeor BMR times an activity factor, adjusted for the user's target rate of loss or gain. User can override with a fixed number.
- Exercise calories (cardio and resistance) are added to the day's budget. Setting for how much to add back: 0%, 50%, 100% (default 100%).
- Macro goals as grams or percentages.
- Goals that imply a very low intake get a plain warning on the goal screen. No lectures, no blocking.

### Other

- Units: pounds/inches by default, metric option.
- Export everything to a single file (JSON and CSV) and import it back. Optional import of the user's own MyFitnessPal export if the format allows.
- About screen: version, source link, license, food data attribution, Buy Me a Coffee row, Send feedback (opens email).

## Speed targets (the acceptance tests for "efficient")

| Task | Target |
|---|---|
| Log a typed 4-item meal | 1 tap to open, type, 1 tap to save |
| Log a saved meal or "same as yesterday" | 2 taps from home screen |
| Log body weight | Under 5 seconds from home screen, or from the widget |
| Start yesterday's or last week's routine | 1 tap from Workouts |
| Log a set using prefilled numbers | 1 tap |
| Log a cardio session | 1 screen |

## Out of scope for version 1

- On-device or cloud AI parsing
- Accounts, cloud sync, social features, sharing, leaderboards
- Meal plans, coaching, articles
- Web or desktop builds
- Wear OS / Apple Watch apps

## Data rules

- Local SQLite database (via a Flutter library chosen in Phase 2). Schema migrations from the first release onward.
- No user data in logs.
- Food database: decide in Phase 2 whether to bundle a trimmed USDA dataset, download it on first run, or both. Barcode lookups to Open Food Facts happen only when the user scans.
