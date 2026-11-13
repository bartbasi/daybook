# Phase 4 summary

Draft. Phase 4 is in progress, and this file is filled in as each step lands. The plan is in [phase-4-plan.md](phase-4-plan.md).

## Status

| Step | State |
|---|---|
| 0 Changes to Phase 2 work | In progress |
| 1 Weight entry and widget | In progress |
| 2 Food parser and meal entry | Not started |
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

## Open questions from the plan, still to confirm

Work is going ahead on the recommended option for each. They are listed in phase-4-plan.md section 9: iPhone signing for the gate (2), Compendium permission (3), cardio general entries (4), imported workouts (5), rest alert timing on Android (6), no exercise images (7), and the "collects no data" line in About (8).

## A question about the "data stays on the device" promise

Found in review of the widget, and true since Phase 2. Android backs up every app's data to the user's own Google account unless the app opts out, and an iPhone does the same to iCloud. Daybook does not opt out today, so with phone backup turned on, Daybook's database is in that backup. Nothing goes to Play, Inc. or anyone else either way.

- (a) **Recommended:** leave phone backups working, and say so plainly in About and the privacy policy: "Daybook sends nothing to us or anyone else. If your phone's own backup is on, it includes Daybook's data like any other app." A person who replaces a phone keeps their history without having to remember to export first.
- (b) Opt out on both platforms, so the data never leaves the phone except through Export. A lost or replaced phone then means lost history unless the user exported.

Nothing has been changed yet. The brief says "All user data stays on the device", so this is yours to decide.

## Review findings worth knowing

- **Weight edit after a unit switch (fixed before release).** Editing only the time of a weigh-in after switching between pounds and kilograms rewrote the stored weight from the rounded number on screen. 50.6 lb could come back as 50.7 lb. An edit now keeps the stored weight unless the number was changed.

## Not finished

- MyFitnessPal import: skipped by Bart's decision in Phase 1.

## To check on your phones

To be filled in from phase-4-plan.md section 7.3 at the end.
