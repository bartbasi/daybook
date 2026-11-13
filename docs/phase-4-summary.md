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

## Open questions from the plan, still to confirm

Work is going ahead on the recommended option for each. They are listed in phase-4-plan.md section 9: iPhone signing for the gate (2), Compendium permission (3), cardio general entries (4), imported workouts (5), rest alert timing on Android (6), no exercise images (7), and the "collects no data" line in About (8).

## Review findings worth knowing

- **Weight edit after a unit switch (fixed before release).** Editing only the time of a weigh-in after switching between pounds and kilograms rewrote the stored weight from the rounded number on screen. 50.6 lb could come back as 50.7 lb. An edit now keeps the stored weight unless the number was changed.

## Not finished

- MyFitnessPal import: skipped by Bart's decision in Phase 1.

## To check on your phones

To be filled in from phase-4-plan.md section 7.3 at the end.
