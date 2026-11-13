# Phase 4 summary

Draft. Phase 4 is in progress, and this file is filled in as each step lands. The plan is in [phase-4-plan.md](phase-4-plan.md).

## Status

| Step | State |
|---|---|
| 0 Changes to Phase 2 work | Done. Reviewed, pushed, CI green |
| 1 Weight entry and widget | Done. Reviewed and pushed. Widgets and timings still need your phones |
| 2 Food parser and meal entry | In progress. Parser, food data layer, live re-parsing, the food entry screen, the correction sheet, the chips row, saved meals, barcode scanning, and the food and recipe editors are done, reviewed and pushed. Still to do: the food and recipe editors, the speed tests |
| 3 Goals and daily budget | Not started |
| 4 Resistance training | Not started |
| 5 Cardio | Not started |
| 6 Summaries | Not started |
| 7 Health sync | Not started |
| 8 About, settings, units | Not started |

## On your phone now

A release build of the work so far was installed on the Z Fold 5 on 2026-11-13, at your request, straight from this machine. No earlier Daybook build was on the phone, so nothing had to be uninstalled. It was replaced the same day with a build of commit b4775a4, installed over the first one, so anything you had logged is still there. It has weight entry, the Weight tab, the weight widget, and food entry: type a meal, tap a line to fix the food or the amount, save, edit or delete a logged meal from Home. There are no chips, saved meals list, barcode scanning or food editor in that build. The app started cleanly with no errors in its own log.

A newer build with the chips, saved meals and barcode scanning (commit 5b643d5) was made on 2026-11-13, but the phone was no longer connected, so it is not installed. Plug the phone in and say so, and it will be installed.

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
27. **The chips are two rows, not one.** The food entry wireframe draws whole meals ("Same as yesterday" and saved meals) in one row and recent and frequent foods in a second, each with its own label and each scrolling sideways. docs/design/speed-targets.md says "one row". The wireframe was followed. A row with nothing to show is left out.
28. **"Same as yesterday" does not count as a use of a saved meal.** It copies yesterday's entries as a new meal and stores no saved meal with it, even when yesterday's meal came from one. So the order of the saved meal chips reflects only the times you logged a saved meal by its chip or its name. Say if a copy should count too.
29. **The recent and frequent foods are from the 30 days up to today**, also when you are filling in an older day.
30. **Closing the saved meal editor with unsaved changes drops them, with no question and no Undo.** The wireframes say nothing here, and the plan allows a confirmation only for Import. The food entry screen offers Undo for typed text; the editor does not. Say if it should.
31. **A saved meal cannot be saved with no items.** The editor says "Add at least one item." To get rid of one, use Delete in its menu, which has Undo.
32. **The saved meal editor has its own copy of the typing code from the food entry screen** (about 250 lines) so that the reviewed food screen did not have to be taken apart. The reviewer checked the copy against the same rules. Sharing the code is a clean-up for later, not a behavior change.
33. **A barcode already on your phone is used without asking Open Food Facts.** If the barcode belongs to a food you made, or to a product you scanned before, the scan uses that food and sends nothing. Any other barcode sends exactly one request. This works with no connection and sends less, but a product scanned before is not refreshed if Open Food Facts later corrects it. The plan said "exactly one request per scan"; this makes it "at most one". Say if a scan should always ask.
34. **"Add it as your own food" after a barcode is not found comes with the food editor** (task 2.12). Until then the message says the product was not found and offers nothing more.
35. **The scan screen has "Type the number instead"**, as the wireframe draws it, built as a number field with Look up and a way back to the camera. A typed number must be 8, 12, 13 or 14 digits and its last digit must check out, so a typo cannot pull up a different product.
36. **Barcodes are kept in one form.** A US 12 digit barcode is stored with a leading 0 (its 13 digit form), and the short barcode on small US packages is expanded to its full form, so a scanned and a typed number are the same product.
37. **Impossible values from Open Food Facts are dropped.** A negative value, more than 100 g of a nutrient in 100 g of food, or more than 900 kcal in 100 g is treated as not listed. A product with no usable calorie value counts as not found.
38. **A product with no serving size on Open Food Facts is added as 100 g and marked Assumed.** One with a serving size is added as 1 serving, as the wireframe shows.
39. **The sheet opened from the saved meal editor has no "Scan its barcode".** Scanning is on the food entry screen only.
40. **The app grew by about 8 MB with the barcode scanner** (36.0 MB for the build on your phone, from 27.9 MB). The plan set 15 MB of growth as the point to stop and ask you. The scanner reads barcodes on the phone with no Google services; that code is the size.
41. **The food editor asks for an amount, a unit (serving, grams or milliliters) and, for a serving, an optional weight.** The wireframe drew "1 [piece] = [ ] g" with a unit you name yourself. The stored food has one built-in serving, so a named unit such as "slice" is added under Portions with its weight. Numbers typed for any amount are stored per serving or per 100: 90 kcal per 50 g is kept as 180 per 100 g, and reads that way when the food is opened again.
42. **The barcode field in the food editor is typed, not scanned.** The wireframe draws a Scan button there. The scan screen as built looks the number up on Open Food Facts, which is not wanted when you are entering your own food. The number is checked the same way as on the scan screen.
43. **Scanned products are listed under "My foods and recipes"**, as the wireframe says, marked as scanned. They cannot be edited. Deleting one (with Undo) is the way to fix a wrong product: the next scan of that barcode asks Open Food Facts again.
44. **Opening a recipe works its numbers out again from its ingredients as they are now.** If an ingredient food was edited since, the recipe shows the new totals and saving stores them. Until you open and save the recipe, typing its name in a meal uses the totals from the last save. Meals already logged never change.
45. **A recipe cannot contain itself**, directly or through another recipe. Its totals would grow on every save.
46. **"Create a food" and "Scan its barcode" are offered only from the food entry screen**, not from the sheet inside the recipe editor or the saved meal editor. To use a new food in a recipe, make the food first.
47. **Deleting a food frees its barcode.** Undo puts it back unless another food took that barcode in between, and says so if it did.
48. **A number typed like "1,000" is refused in the food editor**, with a request to type it without the comma, because it could mean one thousand or one. "1,5" and "0,125" are read as decimals.
49. **Saved meals keep their own copy of each item's numbers.** Editing or deleting a food does not change a saved meal that contains it.
50. **While the keyboard is up, a message on the food entry screen takes the place of the totals line.** On the cover screen at double text size there are 500 dp above the keyboard: the top row, the text box, the totals and Save already fill them, so a message had nowhere to go without cutting something off. The Save button stays, and the totals come back when the message goes or the keyboard goes down. With the keyboard down both show, and every message shows in full. With the keyboard up a message takes at most two fifths of the height above the keyboard; a longer one scrolls, with a scrollbar that is always shown, and never shows less than two full lines. In the tests' wide font the longest message scrolls at double text size; on a phone it should fit in full, which is on the checklist below.
51. **The offer after a barcode is not found reads "No product found for (number). Add it as your own food?" with a button that says "Add it".** The wireframe has the question in the message. The short button always fits without shrinking its text; a screen reader says "Add it as your own food". The message goes after 10 seconds like any other, except when a screen reader is on, when it stays until used.

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

- **A phone that reports no camera at all shows an empty camera area on the scan screen**, with no words. The scanner library says nothing in that case. "Type the number instead" and the X still work.
- **Licence notices for the scanner's built-in code** (zxing-cpp, zint, CameraX) are not collected automatically. They are added to the licence list in About in step 8; docs/dependencies.md carries the note.
- **The saved meal editor does not scroll the line you are typing into view**, as the food entry screen does. With many items and the keyboard up you may have to scroll by hand.
- **Chips look the same for the moment a save is running.** They do nothing then, and the screen closes right after, so no word or shape was added.

- **With a screen reader on, the "Add it" message stays until it is used**, and while the keyboard is up it keeps the totals line hidden. Closing the keyboard brings the totals back. A "Not now" button on that message would be the fix if this turns out to bother anyone.

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

Food entry (step 2, what is built so far), on the Z Fold 5:
- From Home tap + Food, type "2 eggs and toast with butter", and watch the lines appear as you type. They should keep up with your typing, with no stutter.
- Tap a line, pick another food, and save. Type the same words another day: your pick should come first.
- Tap a line and change the amount. Only the numbers and unit in the text should change.
- Type something Daybook cannot know (a brand name, say). The line should say it was not found, and Save should ask you to fix it first.
- Fold and unfold, and rotate, with text typed and with the sheet open. Nothing typed should be lost.
- Close the screen with text typed: Home should offer Undo and bring the text back.
- With the largest font size, every line should wrap and nothing should be cut off.
- TalkBack reads each line as one item with its food, amount and calories.

Barcode scanning (step 2), on the Z Fold 5. None of this has run on a real camera yet:
- Tap Scan on the food entry screen. The phone should ask for the camera the first time, and only then.
- Refuse the camera once: plain words should say what to do, and "Type the number instead" should still work.
- Scan a product. It should appear as a line marked Scanned with the Open Food Facts credit, and the camera light in the status bar should go off when the screen closes.
- Scan the same product again in airplane mode: it should still be added.
- Scan something new in airplane mode: a message within about 10 seconds, and nothing added.
- Try a US product with a 12 digit barcode, and a small package with a short barcode (a can or a pack of gum). Tell me if either is not found when it is on openfoodfacts.org.
- Look at how the amount reads for products whose serving is written like "30 g" or "2 biscuits (25 g)".
- Fold and unfold while the camera is open.
- Type a not found food, tap its line, and use "Scan its barcode" there.
- On the cover screen with the largest font size and the keyboard up, scan something in airplane mode: the message should be readable in full or scroll with a visible scrollbar, the text box and Save should stay in view, and the totals should come back when the message goes.

Weight (step 1), on the iPhone, once there is a signed build (see docs/ios-widget.md for the Apple Developer steps):
- The widget appears in the widget gallery, in the small and medium sizes.
- After a weigh-in the widget shows it. If it only ever shows "Daybook weight", the App Group is missing from one of the two provisioning profiles.
- A tap on the widget opens the weight sheet, with the app closed and with it in the background. If nothing happens, or an error appears, docs/ios-widget.md lists the two one-line fixes to try.
- The number pad on iPhone has no Save key, so Save is the button on the sheet.
