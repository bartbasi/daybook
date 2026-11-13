# Phase 4 summary

Draft. Phase 4 is in progress, and this file is filled in as each step lands. The plan is in [phase-4-plan.md](phase-4-plan.md).

## Status

| Step | State |
|---|---|
| 0 Changes to Phase 2 work | Done. Reviewed, pushed, CI green |
| 1 Weight entry and widget | Done. Reviewed and pushed. Widgets and timings still need your phones |
| 2 Food parser and meal entry | In progress. Parser, food data layer and live re-parsing are done, reviewed and pushed. Screens not started |
| 3 Goals and daily budget | Not started |
| 4 Resistance training | Not started |
| 5 Cardio | Not started |
| 6 Summaries | Not started |
| 7 Health sync | Not started |
| 8 About, settings, units | Not started |

## On your phone now

A release build of the work so far was installed on the Z Fold 5 on 2026-11-13, at your request, straight from this machine. No earlier Daybook build was on the phone, so nothing had to be uninstalled. It has weight entry, the Weight tab, the weight widget and a preview of the food entry screen (typing and saving a meal; tapping a line does nothing yet).

## Before you install the Phase 4 build

Uninstall the Phase 2 test build from your phone first, or clear its data. The database layout changed before any release (see the first decision below), and the old build's database is not migrated.

## Decisions made during the build

Each is the recommended option from the plan's open questions, or a small call made when a review found a problem. Say if you want any changed.

1. **Schema version 1 was amended, with no version 2.** Nothing has been released, and a version 2 would have needed code to read version 1 backups that nobody has. `goals.fixed_calories` became `calories`, and `meals.saved_meal_id` was added so saved meal chips can be ordered by use.
2. **The metric weight range is 22.7 to 453.6 kg**, not the 23 to 450 kg in the wireframe note. That is exactly 50 to 1,000 lb. With the rounder numbers, a weight entered at the pound limit could not be edited after switching to kilograms.
3. **Weigh-ins are listed by their saved day first**, then by time. After travel across time zones, sorting by clock time alone could show an earlier day's weigh-in as the latest.
4. **The "Weight saved" message on Home is a bar above the buttons, with Undo for 10 seconds.** The usual pop-up message at the bottom of the screen would have covered the + Food, Weight and Cardio buttons.
5. **A weigh-in cannot be given a time in the future.** The date picker already stopped at today; a time later today is refused too.
6. **Four Android permissions that the widget library brings in are removed.** The home-screen widget package links Android's WorkManager, which adds wake lock, network state, run at boot and foreground service permissions. Daybook uses none of those features, so the app's manifest removes them. The app still declares only internet access (for barcode lookups) and one standard AndroidX permission.
7. **The widget shows the date of the last weigh-in, not "Today".** For example "Thu, Nov 12, 7:02 am". The widget is only redrawn when the app runs, so "Today" would still be showing the next morning.
8. **The widget's bottom line is always "Tap to log".** The wireframe had "Logged today. Tap to log again" after a weigh-in, which has the same stale-text problem.
9. **The time shown on the weight sheet is the time saved.** That is the moment the sheet opened, or the moment the app last came back to the front with the sheet open, not the moment Save was tapped. A sheet opened at 11:59 pm and saved at 12:01 am stores the weigh-in at 11:59 pm on the day it showed. A sheet left open overnight and saved in the morning stores the morning.
10. **Thirty-eight places where the parser grammar was silent or contradicted itself were settled while building it.** None changes a worked example. They are written into parser-grammar.md, and section 14.3 there lists the ones you would notice, each of which you can overrule. The main ones: a period after a word that only looks like a unit ends the sentence ("I ate a candy bar. Coffee."); a product called "Coca-Cola 330ml" does not stop "330ml milk" meaning 330 ml of milk; your own names of two or more words are kept whole, so a saved "Big Mac" is not read as a large "mac"; "coffee with no sugar" gives one line, not a second "not found" one; "cookie" and "cookies" find the same food; "pb&j" and "pb and j" are the same alias.
11. **Deleting a meal is a real delete, and Undo works while the app stays open.** Weigh-ins are only marked deleted, because a health sync could otherwise bring them back; meals are never synced. Marking meals instead would mean every total in the app has to remember to skip them, and one miss would silently count a deleted meal.
12. **Four synonyms were added to the parser's list:** "skim milk" and "nonfat milk" mean fat free milk, "bbq" means barbecue, and "cereal" alone means ready-to-eat cereal (it had been matching hot cooked cereal with no Guess marker).
13. **Backspacing does not lose a correction.** As first specified, changing "2 slices toast" to "3 slices toast" by backspacing the 2 dropped the bread you had picked, because for one keystroke the item read as a different food. A picked food is now held while you keep editing that same item and comes back when its words match again. It is dropped once you move on to another item, or if you delete the item.
14. **The unit picker in the correction sheet offers only what can be typed.** Changing an amount there rewrites the text, and some portion names cannot be typed back ("drink (12 fl oz)"). The picker lists grams, ounces and the portions that read back as the same thing, and every rewrite is checked before it is applied.
15. **Aliases are stored as you typed them.** They are compared on the fly, so a later change to the comparison rules cannot make saved aliases stop working. A test also pins the keys the app stores for learned corrections: after release, changing one means migrating stored data.
16. **The speed tests run in their own CI step.** Run beside the rest of the suite they failed once from machine load alone. The budgets are unchanged.
17. **Editing a logged meal has no Undo.** Saving an edit replaces the meal's lines, and the earlier version is not kept. Deleting a whole meal, and saving a new one, both offer Undo. Say if you want Undo after an edit too; it needs a little more in the data layer.
18. **Undo of a saved meal keeps what the app learned from it.** If you corrected "toast" to a bread, saved, then tapped Undo, the meal is removed but the correction is still remembered.
19. **Home lists each meal's foods by the first word of their names** ("Egg, Bread, Butter, Coffee, Cream"). The wireframe showed the words as typed; a stored line keeps the food's name, not the typed words.
20. **A count with no unit is shown as "2, 100 g".** Some wireframe frames showed "2 egg, 100 g"; the grammar gives a count no unit word.
21. **On the food screen the text box is always at the top, under the meal chips.** Lines that were not typed (a logged meal being edited, and later scans and chips) are listed under it, before the typed lines. Two wireframe frames drew them above the box; keeping the box fixed is what stops it scrolling out of view while you type.
22. **Changing one item of a typed saved meal turns it into its items for that meal.** If you type "usual breakfast" and then change or remove one of its items, the saved meal's name is replaced by its items as ordinary lines, and the change applies to that line. The saved meal itself is not altered and nothing is learned from it.
23. **No dotted underline in the text box under a picked item's words.** The wireframe drew one. Styling part of a live text field risks the keyboard's own composing and selection, so the line under the box carries the "Your pick" marker instead.
24. **At double text size on the cover screen, with the keyboard up and an item not found, there is no room for the lines.** The top row, the text box and the "Fix 1 item" button stay on screen, and the lines come back when the keyboard goes down. Text is never shrunk to make room.
25. **A food you pick for a line that was not typed (a logged meal being edited, a scan, a chip) is not marked "Your pick" and is not learned.** Learning is tied to the words you typed, and such a line has none.
26. **When nothing matches in the correction sheet's search, the sentence saying so sits under the search box.** The wireframe had it above; at large text it pushed the box out of view.

## Open questions from the plan: answered

Bart approved the recommended option for each on 2026-11-13 ("your recommendations are approved"). They are in phase-4-plan.md section 9:

- **iPhone for the gate (2):** signing and TestFlight setup move to the end of Phase 4. You do the Apple Developer account steps by hand; docs/ios-widget.md lists what the widget needs.
- **Compendium permission (3):** cardio is built with the 2024 values now, and the reply (or your decision to go ahead without one) is a condition of release in Phase 6. The email is still yours to send.
- **Cardio with no distance typed (4):** the Compendium's general entry for the activity (Running 12145, Walking 17190, Bicycling 01014).
- **Imported workouts (5):** every session from Health Connect or Apple Health is imported; a strength session logged in both places counts twice until one is deleted.
- **Rest alert on Android (6):** no extra permission; the alert may be a few seconds late.
- **Exercise images (7):** none shipped, and the "Some illustrations by Everkinetic" sentence is dropped from About.
- **Items missing from the brief (8):** only a one-line "Daybook collects no data" statement in About is added. First-run setup, hiding the weight on the widget, a weight typo check and calorie quick-add wait for the Phase 5 friction log.

## Phone backups and the "data stays on the device" promise: answered

Android backs up every app's data to the user's own Google account unless the app opts out, and an iPhone does the same to iCloud. Daybook does not opt out, so with phone backup turned on, Daybook's database is in that backup. Nothing goes to Play, Inc. or anyone else either way.

Bart approved the recommended option on 2026-11-13: phone backups keep working, and About and the privacy policy say so plainly: "Daybook sends nothing to us or anyone else. If your phone's own backup is on, it includes Daybook's data like any other app." Someone who replaces a phone keeps their history without having to export first. The About wording is added in step 8.

## The model rule in CLAUDE.md

CLAUDE.md says agents use Sonnet 5.5 or Opus 5.5 only, never Fable. In this phase every implementation agent ran on Sonnet 5.5 or Opus 5.5 and every reviewer on Opus 5.5. The session that coordinates them, makes the rulings recorded above, writes this summary and makes the commits has been running on Fable 5.2, and the commits carry that name in their co-author line. That goes against the rule as written. You were asked to either add a line to CLAUDE.md allowing the coordinating session to run on Fable, or switch the session's model. On 2026-11-13 you said to continue and that the recommendations were approved, without naming this point, so the work has continued the same way and CLAUDE.md is unchanged. If you want the rule to match what is happening, add that line to CLAUDE.md yourself, or switch the model.

## Review findings worth knowing

- **Weight edit after a unit switch (fixed before release).** Editing only the time of a weigh-in after switching between pounds and kilograms rewrote the stored weight from the rounded number on screen. 50.6 lb could come back as 50.7 lb. An edit now keeps the stored weight unless the number was changed.
- **Two midnight bugs found by the independent test pass (fixed).** With the app left open across midnight, Home kept showing yesterday as today and a new weigh-in was not called "today". And a weigh-in typed before midnight but saved after it was stored under the next day although the sheet showed the earlier time.

## First guesses that are plainly wrong

A reviewer tried about 190 everyday foods through the parser. Most were right. These come back wrong, all marked Guess, so one correction fixes each for good. In Phase 3 you chose to accept poor single-word defaults and look again after using the app (grammar open question 7). This is the list to look at then.

| Typed | First guess |
|---|---|
| tofu | Tofu yogurt |
| spaghetti | Spaghetti sauce |
| granola | Cookie, granola |
| chocolate | Chocolate milk |
| peas | Blackeyed peas |
| salad | Cabbage salad |
| caesar salad | Caesar dressing |
| egg roll | Egg bread roll |
| pop tart | Freezer pop |
| curry | Beef curry |
| oreos | A McFlurry with Oreo cookies |
| sparkling water | A branded mineral water |
| walnuts | Walnut oil |
| pizza | Pizza rolls |
| tea | Ginger tea |
| cream | Ice cream |

Parser speed on the development machine, against the budgets (a phone will be slower, and must be measured):

| What | Budget | Measured |
|---|---|---|
| Typing the example meal, per keystroke, through the background worker | 8 ms at the 95th percentile | about 2 ms |
| Typing misspelled words, per keystroke | 8 ms at the 95th percentile | about 3.8 ms; worst single keystrokes 8 to 10 ms |
| A 10-item meal of foods not seen before | 25 ms | about 10 ms |
| Building the food index at start | 1,500 ms | about 350 ms |

Two more behaviors to know about:
- "coffee, black" reads "black" as a second food and guesses black beans. "black coffee" is fine.
- "kiwis" and other plurals of words ending in "i" ("zucchinis", "martinis") are not reduced to the singular, because of an exception meant for words like "basis". They still find the food through typo correction, as a guess.
- Amounts a reviewer found odd while testing the correction sheet: "2 strips bacon" does not read "strips" as a unit, so the amount is assumed (16 g); "half an avocado" comes to 15 g; "1 glass orange juice" is assumed at 248 g; and for cheddar, a typed "1 slice" means a 9 g cracker-size slice.
- A word that is spelled right but is not in the USDA data can be "corrected" into another food as a guess: "skyr" becomes a Skor toffee bar.

## Known gaps to decide later
- **A changed amount is written with a singular unit.** Changing "2 slices sourdough toast" to 3 in the correction sheet gives "3 slice sourdough toast". It reads back as the right food and amount; only the wording is off. The fix belongs in the parser's rewrite (write the unit's own plural when the amount is not 1).
- **Changing the food on a counted line keeps the count, not the weight.** "4 eggs" changed to oatmeal gives 4 cups of oatmeal, not the eggs' 200 g. The amount as written is tried first and the weight second. Say if you would rather the weight came first for plain counts.

- **Text typed in the food box is lost if Android kills the app in the background** (for example after switching to another app for a while). The text is kept through folding, rotation and a failed save, and closing the screen offers Undo, but it is not written to disk until Save. Saving a draft when the app is paused would cover it.

## Not finished

- MyFitnessPal import: skipped by Bart's decision in Phase 1.

## To check on your phones

More is added as each step lands. The full list comes from phase-4-plan.md section 7.3.

Weight (step 1), on the Z Fold 5:
- Log a weight from Home with a stopwatch: tap Weight, type, tap Save. The target is under 5 seconds.
- Add the "Daybook weight" widget from the widget picker. It is blank until the app has run once.
- The widget shows the right text at its normal size and when shrunk to 2 by 1, in light and dark, and with the largest font size.
- Tap the widget with the app closed and with it in the background. It should open on the weight sheet. Time the closed case: the target is under about 1.5 seconds to the sheet.
- After a save, the widget shows the new weight.
- Reopen the app from Recents after swiping it away: the weight sheet should not open by itself.
- Fold and unfold with a number typed in the sheet: the number stays.
- TalkBack reads the widget once, as one button.

Weight (step 1), on the iPhone, once there is a signed build (see docs/ios-widget.md for the Apple Developer steps):
- The widget appears in the widget gallery, in the small and medium sizes.
- After a weigh-in the widget shows it. If it only ever shows "Daybook weight", the App Group is missing from one of the two provisioning profiles.
- A tap on the widget opens the weight sheet, with the app closed and with it in the background. If nothing happens, or an error appears, docs/ios-widget.md lists the two one-line fixes to try.
- The number pad on iPhone has no Save key, so Save is the button on the sheet.
