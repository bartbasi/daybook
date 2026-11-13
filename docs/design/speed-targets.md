# Speed targets: tap counts

Phase 3 design. Each target from BRIEF.md, the exact tap sequence in the wireframes, the count, and pass or fail.

How taps are counted:
- Every touch on the screen counts: buttons, chips, fields, keyboard action keys (Next, Done, Save), and anything that opens or closes a keyboard, sheet or message.
- Typing the content itself (letters, digits, commas) is the "type" part of a target and is listed separately as keys.
- Where a target is in seconds, the time is an estimate: about 0.5 s per tap that needs aiming, about 0.35 s per key on the number pad. These estimates must be checked with a stopwatch on the phone in Phase 4.
- Android and iPhone keyboards differ. The iPhone decimal pad (used for weight and cardio numbers) has no Next, Done or Save key. Where that matters, the count below uses on-screen buttons and fields, and says whether the count changes.

## Summary

| Target | Brief says | Design | Result |
|-|-|-|-|
| Log a typed 4-item meal | 1 tap to open, type, 1 tap to save | 1 tap, type, 1 tap | Pass |
| Log a saved meal or "same as yesterday" | 2 taps from home | 2 taps | Pass (decision below) |
| Log body weight | Under 5 s from home, or from the widget | Home: 2 taps + 5 keys, about 3 to 3.5 s. Widget: about 3.5 to 5 s | Pass on estimate; widget depends on app start time |
| Start yesterday's or last week's routine | 1 tap from Workouts | 1 tap | Pass |
| Log a set using prefilled numbers | 1 tap | 1 tap | Pass |
| Log a cardio session | 1 screen | 1 screen, 3 taps + numbers (Android and iPhone) | Pass |

## 1. Log a typed 4-item meal

Wireframe: [food-entry.html](food-entry.html), frames 1 and 3.

1. Home: tap **+ Food**. (tap 1)
   The entry screen opens with the cursor in the text box and the keyboard up. Meal comes from the clock, date is today. No tap is needed to start typing.
2. Type `2 eggs, 2 slices sourdough toast, 1 tbsp butter, coffee with 2 tbsp half and half`. (keys only)
   Lines are parsed again on every change to the text. This is example 1 in docs/parser-grammar.md: 5 lines, 490 kcal, half and half shown as a Guess, coffee with an Assumed amount.
3. Tap **Save** in the bar above the keyboard. (tap 2)
   The keyboard does not need to be closed first.

**Count: 2 taps (1 to open, 1 to save). Pass.**

Conditions:
- Every item ends up as a match, a guess, or an assumed amount. Guesses and assumed amounts do not block Save.
- If an item is **not found**, nothing is saved and the count grows (frames 6a, 6b and 7):
  - while the cursor is still in that item, the line is drawn as plain typing and the button reads Save; tapping it marks the item not found and opens its sheet;
  - once the cursor has left it, the button reads "Fix 1 item" and opens the same sheet;
  - then: search and pick a food (about 2 taps), or Remove from meal (1 tap), then Save. That is 4 taps or more in all.
- If the meal is not the one the clock picks (for example lunch at 10:15), add 1 tap on the meal chip. Logging for yesterday adds 1 tap on the < arrow.
- Dictation with the keyboard's mic key adds 1 tap and replaces the typing.

## 2. Log a saved meal or "same as yesterday"

Wireframe: [food-entry.html](food-entry.html), frames 1 and 12.

1. Home: tap **+ Food**. (tap 1)
2. Tap the **Same as yesterday** chip, or a saved meal chip such as **Usual breakfast**. (tap 2)
   The meal is logged at once into the current meal and date. The screen closes, and Home shows "Breakfast logged: same as yesterday, 308 kcal" with **Undo** for 10 seconds.

**Count: 2 taps. Pass.**

Conditions:
- The text box is empty and there are no lines yet. Once there is text or a line, these chips add their items as added lines instead (the label above them says so), so nothing already entered is lost. That case is 3 taps (+ Food, chip, Save) plus whatever was entered.
- The meal from the clock is the right one. Otherwise add 1 tap on the meal chip first.
- The chip is in view. Chips sit in one row that scrolls sideways; "Same as yesterday" is always first, then saved meals in order of how often they are used in this meal. A saved meal further along needs a swipe.
- "Same as yesterday" appears only when yesterday has food in this meal.

Why it is not dangerous: the chip shows the meal name, item count and kcal before it is tapped; Undo is offered at once; and the logged meal stays on Home, where it can be opened and deleted later.

### Decision for Bart: chip logs at once

| Option | Taps | Notes |
|-|-|-|
| **Chosen:** chip logs at once when the box is empty and there are no lines, with Undo | 2 | Meets the target. One rule to learn: whole-meal chips log, food chips add a line. |
| Rejected: chip adds the meal's items as lines, then Save | 3 | Safest and most consistent (nothing logs without Save), but fails the target. |
| Rejected: chips for saved meals and "same as yesterday" on Home itself | 1 | Fastest, but clutters Home, repeats the list on two screens, and makes a stray tap while scrolling Home log a whole meal. |

If Bart prefers the 3-tap version, the only change is the chip's behavior; the screens stay the same.

## 3. Log body weight

Wireframe: [weight.html](weight.html), frames 1 to 3 and 8 to 10.

From Home:
1. Tap **Weight**. (tap 1)
   A sheet opens with the last weight (182.4) selected and the number pad up.
2. Type `181.8`. (5 keys)
3. Tap **Save**, next to the box. (tap 2)
   On Android the number pad's action key is also Save and can be used instead. The iPhone decimal pad has no action key, so on iPhone it is always the Save button. **The count is the same on both: 2 taps.**
   The sheet closes after the database write returns, and Home says "Weight saved: 181.8 lb, today 7:02 am".

**Count: 2 taps + 5 keys. Estimate: about 0.5 + 0.3 (sheet opens) + 1.75 + 0.5 = 3 to 3.5 seconds. Pass on estimate.**
If the weight is the same as last time: 2 taps, about 1.5 seconds.

From the widget:
1. Tap the **widget**. (tap 1)
   Daybook opens straight to the same sheet, prefilled.
2. Type the weight. (5 keys)
3. Tap **Save**. (tap 2)

**Count: 2 taps + 5 keys, plus the time the app takes to open. Estimate: about 3.5 to 5 seconds. Pass only if the app opens to the sheet in under about 1.5 seconds from cold.** A warm start (app already in memory) is well under that. This must be measured on the Z Fold 5 and the iPhone in Phase 4; if cold start is too slow, the fix is a lighter first screen for the widget route, not a different widget design.

### Decision for Bart: widget opens a quick-entry view

| Option | Notes |
|-|-|
| **Chosen:** the whole widget is one tap target that opens the weight sheet | One write path for weight (same code, same tests), any value can be typed, works on all iOS versions with widgets. Costs the app start time. |
| Rejected: - and + steppers with Save on the widget | No app start, but a 0.6 lb change is 4 taps and 2 lb is 11; needs iOS 17 or later for buttons; the widget would write to the database from a separate process (a second write path for the most reliability-critical data); and it is easy to set off from a pocket. |

Home-screen widgets on Android and iOS cannot hold a text box, so a typed value on the widget itself is not possible.

## 4. Start yesterday's or last week's routine

Wireframe: [workout.html](workout.html), frames 1 and 2.

1. Workouts tab: tap **Start** on "Yesterday, Wed, Nov 11: Legs" or "Last Thursday, Nov 5: Push A". (tap 1)
   The workout opens with every set prefilled from the last time each exercise was done.

**Count: 1 tap from the Workouts tab. Pass.** From Home it is 2 (Workouts tab, Start).

Conditions:
- A workout was logged on that day.
- "Start again" always shows yesterday's workout first and the workout from the same weekday last week second, when they exist, then other recent ones. So both targets are always the first two rows, in view without scrolling.
- No other workout is running. If one is, the Start buttons are replaced by "Return to workout".
- Starting a routine from its own row under Routines is also 1 tap.

## 5. Log a set using prefilled numbers

Wireframe: [workout.html](workout.html), frames 2 and 3.

1. Active workout: tap the **check button** at the end of the set row. (tap 1)
   The set row, stored as not completed when the workout started, is marked completed at once with the weight and reps shown. It shows Done, and the rest timer starts.

**Count: 1 tap. Pass.**

Conditions:
- The exercise has been done before. The first time, weight and reps are empty and have to be typed (tap weight, type, tap reps, type, check).
- The set is on screen. After each logged set the list scrolls so the next set is in view.
- No permission prompt can appear in this path. The rest timer runs inside the app and needs no permission. A one-time row on the timer bar, "Alert me when rest ends", asks for notification permission only when the user taps it.

For comparison, changing a set before logging it (frame 4): the number, +5, +1, Done, check = 5 taps for the example (175 x 7 to 180 x 8). One step on one value is 4.

## 6. Log a cardio session

Wireframe: [cardio.html](cardio.html), frames 1 and 2.

1. Home: tap **Cardio**. (tap 1)
   The last activity (Running) is already picked. Duration has the cursor and the number pad is up.
2. Type `30`. (2 keys)
3. Move to Distance: on Android tap **Next** on the number pad; on iPhone, whose decimal pad has no Next key, tap the **Distance** field. (tap 2 either way)
4. Type `3.1`. (3 keys)
5. Tap **Save** in the bar. (tap 3)

**Count: 1 screen; 3 taps + 5 keys on both Android and iPhone. Pass.**

The estimate: 3.1 mi in 30 min is 6.2 mph, inside the 2024 Compendium band "Running, 6 to 6.3 mph" (code 12050, 9.3 MET). 9.3 x 82.46 kg x 0.5 h = 383 kcal.

Conditions and extras:
- First use: there is no recent activity yet, so nothing is picked. Tap **Other...**, type to search, and pick the activity: about 2 more taps plus a few keys.
- A different activity adds 1 tap (its chip) or a search (Other...).
- Heart rate is optional: tap the field, type, about 1 tap + 3 keys.
- Overriding the calorie estimate: tap the field, type, about 1 tap + 3 keys.

### Decision for Bart: preselect the last activity

Chosen: the most recent activity is picked when the screen opens, so a repeat run needs no activity tap. Rejected: nothing picked, which adds 1 tap every time but can never log the wrong activity without the user picking it. The picked activity is always shown in bold above the fields.

## Measuring these in Phase 4

- Targets 1, 2, 4, 5 and 6 can be integration tests that count taps: drive the app from Home with only the listed taps and text entry, then check the database.
- Target 3 needs two checks: an integration test for the taps (2 + keys), and a timing check on real phones for app start from the widget.
