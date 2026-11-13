# Phase 3 summary

Design only. No app code changed in this phase.

## What was done

1. **Wireframes** in [docs/design/](design/index.html): plain HTML that opens straight from disk, with no scripts and no network use.
   - The eight screens PHASES.md lists:
     - [Home](design/home.html)
     - [Food entry](design/food-entry.html), with the live parse lines and the correction flow (14 frames)
     - [Weight](design/weight.html), with the home-screen widget on Android and iPhone
     - [Workout](design/workout.html), with prefilled sets and the rest timer
     - [Cardio](design/cardio.html)
     - [Summary](design/summary.html), daily and weekly
     - [Goals](design/goals.html)
     - [About](design/about.html)
   - Five supporting screens the brief needs but PHASES.md does not list: [Settings](design/settings.html), [Saved meals and aliases](design/saved-meals.html), [Custom food and recipe editor](design/food-editor.html), [Routine editor](design/routine-editor.html) and [Exercise detail](design/exercise-detail.html).
   - Every page has links that redraw its frames at 344 dp (Z Fold 5 cover screen) and 673 dp (unfolded). Nothing needs more than 344 dp. Unfolded, the layout stays one column, centered, up to 600 dp wide.
2. **Tap counts** for each speed target in [design/speed-targets.md](design/speed-targets.md), and on the page of the screen each one belongs to.
3. **Parser grammar** in [parser-grammar.md](parser-grammar.md): how text is split into items, quantities, units, matching, aliases and saved meals, learning from corrections, the line states, a formal grammar, and 88 worked examples that become the Phase 4 unit tests. The example numbers were produced by a throwaway prototype run against the real bundled USDA data.

## How to look at it

Open `docs/design/index.html` in a browser. Each page shows several phone frames side by side with notes beside them. The Food entry page is the one to read first.

## Navigation

- Bottom bar: Today (Home), Summary, Workouts, Weight, More.
- One tap from Home: + Food, Weight (a sheet), Cardio, any logged item (to edit it), and today's summary.
- Under More: Goals, saved meals, my foods and recipes, exercises, Settings, About.

## Speed targets

| Target | Brief | Design | Result |
|-|-|-|-|
| Log a typed 4-item meal | 1 tap to open, type, 1 tap to save | + Food, type, Save | Pass, as long as no item is "not found" |
| Log a saved meal or "same as yesterday" | 2 taps from Home | + Food, then the chip | Pass (the chip logs at once, with Undo) |
| Log body weight | Under 5 seconds from Home, or from the widget | 2 taps and 5 keys. About 3 to 3.5 s from Home, about 3.5 to 5 s from the widget | Pass on estimate. The widget needs the app to open in under about 1.5 s |
| Start yesterday's or last week's routine | 1 tap from Workouts | 1 tap | Pass |
| Log a set using prefilled numbers | 1 tap | 1 tap | Pass, once the exercise has been done before |
| Log a cardio session | 1 screen | 1 screen, 3 taps and 5 keys | Pass. First use needs an activity search |

The times are estimates from counting taps and keys. They have to be measured on the phones in Phase 4. The conditions behind each count are in speed-targets.md.

## Review

An Opus reviewer that wrote neither document checked both against BRIEF.md, CLAUDE.md, the schema and the real food data. The first pass found 16 issues. The important ones:

- The wireframes and the grammar were written at the same time and disagreed on the brief's own example meal (446 kcal against 490, and different foods). The grammar's numbers match the database, so the wireframes were redrawn from it.
- The cardio wireframe used the 2011 MET value for running at 6 mph (9.8). The 2024 Compendium lists 9.3, so the sample 30 minute run is 383 kcal, not 404.
- Writing a scanned or recent food's name into the text box would have broken, because USDA names contain commas and "and" and would re-parse as several foods. Foods added without typing are now their own lines (see the decisions below).
- Several dictated inputs broke the splitting rules, for example "black coffee two eggs and toast" and "two eggs a banana". The rules were fixed and each input is now a worked example.
- Some buttons and links were smaller than the 48 dp the design promises.
- A notification permission prompt would have appeared while logging the first set. Rest alerts are now something the user turns on from the timer bar.

All 16 were fixed. A second pass by the same reviewer confirmed that, re-checked the redrawn frames and 13 of the new grammar examples against the database, and found 9 smaller issues. The most serious was that a new rule for names like "V8" broke the "x3" multiplier in two examples. Those were fixed as well. That last round of fixes was checked by the lead, not by a third review pass.

## Decisions that need your answer

These change what gets built. My recommendation is first in each.

1. **A saved meal chip logs at once, with Undo.** Tapping "Same as yesterday" or a saved meal on the Food screen logs it straight away when the box is empty. That is the only way to meet "2 taps from Home". The alternative is that the chip fills the meal and you tap Save, which is 3 taps and misses the target.
2. **"Same as yesterday" means yesterday's same meal** (yesterday's breakfast when logging breakfast). The other reading is all of yesterday's food.
3. **Save does nothing while an item is "not found".** The button reads "Fix 1 item" and opens that line. Nothing typed is ever dropped. The alternative is to save the rest and keep a 0 kcal placeholder, which is faster but leaves the day's totals wrong.
4. **An unknown word still gets a guess.** "zorbo bar" becomes a guess of "Breakfast bar, NFS", marked Guess, and Save is not blocked. The alternative treats any item with an unknown word as not found. That is safer, but "leftover pizza" and store brand names would block Save every time.
5. **The weight widget opens the app on a prefilled weight sheet.** Widgets on both platforms cannot hold a text box. The alternative is plus and minus buttons on the widget, which need iOS 17, take many taps for a bigger change, and add a second way of writing weight to the database.
6. **Exercise calories use MET x kg x hours.** That is the plain reading of the brief. It counts resting energy that the daily goal already includes, so a 30 minute run is credited about 41 kcal twice at 100% add-back. The alternative is (MET minus 1) x kg x hours. This changes every exercise number.
7. **A cardio pace between two Compendium entries uses the nearer one, and the slower one on a tie.** The 2024 Compendium lists running speeds as bands (6 to 6.3 mph, then 6.7 mph), so the strict reading you chose in Phase 1 needs a rule for the gaps.
8. **The calculated calorie goal is fixed when Goals is saved.** It stays until you save Goals again or tap Recalculate, so past days keep the goal they had. The alternative recomputes it from your weight every day, which moves it a few kcal a day (2,142 at 182.4 lb, 2,138 at 181.8 lb) and changes past days when a weigh-in is edited.
9. **Keep USDA's default portion.** The grammar uses the FNDDS "Quantity not specified" portion as the amount when none is typed (egg 50 g, butter 14 g, coffee 360 g). The Phase 2 build drops that portion today, so this means a small change to `tools/build_food_db.py` in Phase 4. Without it, coffee defaults to 480 g and drinks in general get worse defaults.

## Decisions made (say if you want any changed)

Food entry:
- Foods added without typing (barcode, a recent or frequent chip, a meal being edited) are "added lines" outside the text box. The app never writes food names into the box. This follows the brief's wording that a barcode "adds a line".
- Editing a logged meal shows its stored lines with an empty box for typing more. Lines you do not touch never change.
- "and" and "with" always split, except inside a short tested list of food names such as "half and half" and "mac and cheese".
- A range such as "2-3 eggs" uses the midpoint and is marked Assumed.
- "oz" means fluid ounces when the food has a fluid ounce portion, and weight otherwise.
- A line is "matched" only when every typed word is found and the food has no extra words, or you have logged it before. Anything else is a guess. A looser rule matched more but confidently picked "Walnut oil" for "walnuts".
- A correction is remembered when the meal is saved, not the moment it is picked.
- Your own foods and recipes win over USDA foods when the last word of their name was typed ("chili" finds your "Turkey chili").
- Closing the Food screen with text in the box closes at once and offers Undo on Home. No "are you sure" popup.
- The full list, with the rejected alternative for each, is in parser-grammar.md section 14.

Weight, workouts and cardio:
- The trend line moves 10% of the way toward each day's weight. Several weigh-ins in one day are averaged.
- Weights from 50 to 1,000 lb are accepted.
- Estimated 1-rep max uses the Epley formula. Personal records are heaviest weight and best estimated 1-rep max.
- Weekly volume counts sets per primary muscle group.
- "Repeat a previous workout" copies its exercises and set counts, filled with the numbers from the last time each exercise was done.
- A strength workout's calories use one MET value (3.5, Compendium code 02054) times body weight times duration.
- Cardio opens with the last activity already picked.

Goals and summary:
- The low intake warning shows under 1,500 kcal a day for men and 1,200 for women, as one sentence with no advice.
- Rate choices are 0.25 to 2 lb a week, at 3,500 kcal per lb.
- Other nutrient goals start at the US Daily Values.
- A week is Monday to Sunday. Averages are over days with food logged.

## Proposed changes to Phase 2 work

Nothing was changed in this phase. These would be made in Phase 4 if you approve them. No version has been released, so there is no user data to migrate.

- **Food data build:** keep the FNDDS "Quantity not specified" portion (decision 9 above).
- **Goals table:** store the calculated calorie number (decision 8 above). It fits the existing `fixed_calories` column, renamed `calories`, with `calorie_mode` still saying whether the number was calculated or typed. That is a schema version bump and a new export fixture.
- **Optional:** a `saved_meal_id` on meals, so saved meal chips can be ordered by how often each is used in that meal slot. Without it the order is a guess from the meal's text.

## Missing from the brief (listed, not drawn)

- A "collects no data" line in About.
- A first-run setup. Only a "Set your goals" card on Home is drawn.
- An option to hide the weight number on the widget, since anyone who sees the phone can read it.
- A check for weight typos (for example 1,824 for 182.4).
- Quick-add of a calorie number with no food.

## Not done or not checked

- Nothing was run on a phone. Keyboard heights, large text settings, app start time from the widget and every time estimate are unmeasured.
- The parser's speed targets (16 ms per keystroke, 50 ms for a 10 item meal) are targets, not measurements. Only a Python prototype exists, outside the repo.
- How Android and iPhone dictation punctuate a spoken meal is assumed, not tested.
- Only the two MET values the wireframes use (running 9.3, strength training 3.5) were checked against the 2024 Compendium.
- Some wireframe numbers are placeholders and are marked as such: the scanned product, the custom food, the week's daily totals, and the activity names in the cardio search.
- The Compendium permission email is still for you to send (draft in phase-1-summary.md).
- This phase's agents (wireframes, grammar, reviewer) ran on Opus 5.5. The session that coordinated them and wrote this summary was running on Fable 5.2, which CLAUDE.md does not allow. Say if you want any of it redone.

## Gate

Phase 3 is done. Waiting for Bart to approve the wireframes and the parser grammar, and to answer the nine decisions above, before starting Phase 4.
