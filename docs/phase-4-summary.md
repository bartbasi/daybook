# Phase 4 summary

Draft. Phase 4 is in progress, and this file is filled in as each step lands. The plan is in [phase-4-plan.md](phase-4-plan.md).

## Status

| Step | State |
|---|---|
| 0 Changes to Phase 2 work | Done. Reviewed, pushed, CI green |
| 1 Weight entry and widget | Done. Reviewed and pushed. Widgets and timings still need your phones |
| 2 Food parser and meal entry | In progress. The parser passes all 88 worked examples; screens not started |
| 3 Goals and daily budget | Not started |
| 4 Resistance training | Not started |
| 5 Cardio | Not started |
| 6 Summaries | Not started |
| 7 Health sync | Not started |
| 8 About, settings, units | Not started |

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

## Open questions from the plan, still to confirm

Work is going ahead on the recommended option for each. They are listed in phase-4-plan.md section 9: iPhone signing for the gate (2), Compendium permission (3), cardio general entries (4), imported workouts (5), rest alert timing on Android (6), no exercise images (7), and the "collects no data" line in About (8).

## A question about the "data stays on the device" promise

Found in review of the widget, and true since Phase 2. Android backs up every app's data to the user's own Google account unless the app opts out, and an iPhone does the same to iCloud. Daybook does not opt out today, so with phone backup turned on, Daybook's database is in that backup. Nothing goes to Play, Inc. or anyone else either way.

- (a) **Recommended:** leave phone backups working, and say so plainly in About and the privacy policy: "Daybook sends nothing to us or anyone else. If your phone's own backup is on, it includes Daybook's data like any other app." A person who replaces a phone keeps their history without having to remember to export first.
- (b) Opt out on both platforms, so the data never leaves the phone except through Export. A lost or replaced phone then means lost history unless the user exported.

Nothing has been changed yet. The brief says "All user data stays on the device", so this is yours to decide.

## The model rule in CLAUDE.md

CLAUDE.md says agents use Sonnet 5.5 or Opus 5.5 only, never Fable. In this phase every implementation agent ran on Sonnet 5.5 or Opus 5.5 and every reviewer on Opus 5.5. The session that coordinates them, makes the rulings recorded above, writes this summary and makes the commits has been running on Fable 5.2, and the commits carry that name in their co-author line. That goes against the rule as written. It needs your answer: either add a line to CLAUDE.md allowing the coordinating session to run on Fable, or switch the session's model. Carrying on with the work is not an answer to it.

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

Two more behaviors to know about:
- "coffee, black" reads "black" as a second food and guesses black beans. "black coffee" is fine.
- A word that is spelled right but is not in the USDA data can be "corrected" into another food as a guess: "skyr" becomes a Skor toffee bar.

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
