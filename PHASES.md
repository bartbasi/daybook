# Daybook: Phases and Kickoff Prompts

Each phase ends at a gate. Paste the kickoff prompt into Claude Code to start that phase. Do not start the next phase until the gate is approved.

---

## Phase 1: Survey (docs only, no app code)

**Goal:** Know what exists before building.

**Kickoff prompt:**

> Read BRIEF.md and CLAUDE.md. This is Phase 1. Write docs only, no app code.
> 1. Survey existing open-source nutrition and workout trackers (start with OpenNutriTracker and Waistline). For each: license, platforms, what they do well, where entry is slow. Note anything worth borrowing as an idea.
> 2. Verify licenses and terms for: USDA FoodData Central, Open Food Facts, an open exercise library (find the best candidate), and a source of MET values for cardio. Confirm each is usable in this project and what attribution it needs.
> 3. Write a feature inventory of what MyFitnessPal tracks, from public information and normal use only. No decompiling, scraping, or API calls.
> 4. Find out what MyFitnessPal's user data export contains, if anything, so we know whether import is possible.
> Write results to docs/survey.md and docs/data-sources.md. Then write docs/phase-1-summary.md and stop.

**Gate:** Bart approves the survey and confirms the data sources.

---

## Phase 2: Foundation

**Goal:** Project skeleton, data model, and food data working with real numbers.

**Kickoff prompt:**

> Read BRIEF.md, CLAUDE.md, and docs/survey.md. This is Phase 2.
> 1. Create the Flutter project (package io.github.bartbasi.daybook). Set up LICENSE and attribution from WoodLogic.
> 2. Design the local database schema for foods, nutrients, meals, meal entries, saved meals, aliases, weight, exercises, routines, sets, cardio sessions, and goals. Include migrations. Write docs/data-model.md.
> 3. Decide how the USDA data ships (bundled, downloaded, or both) and explain the tradeoff in app size and first-run time.
> 4. Load USDA data and wire Open Food Facts barcode lookup.
> 5. Build export and import (JSON and CSV) with tests.
> 6. Set up CI: Android build on every push, iOS build on a cloud macOS runner.
> Write docs/phase-2-summary.md and stop.

**Gate:** Bart sees correct nutrition numbers for a handful of foods he picks, and an export/import round trip works. Both Android and iOS CI builds pass.

---

## Phase 3: Interaction design

**Goal:** Every screen designed and scored against the speed targets before it is built.

**Kickoff prompt:**

> Read BRIEF.md and CLAUDE.md. This is Phase 3. Design only, no feature code.
> Produce wireframes (simple HTML or images in docs/design/) for: home screen, one-screen food entry including the live parse lines and correction flow, weight entry and widget, workout logging with prefilled sets, cardio entry, daily and weekly summary, goals setup, and About.
> For each speed target in BRIEF.md, count the taps in the design and show the count.
> Specify the text parser's grammar: quantities, fractions, units, "with", "and", commas, aliases, and how ambiguous matches are shown.
> Write docs/phase-3-summary.md and stop.

**Gate:** Bart approves the wireframes and the parser grammar.

---

## Phase 4: Build version 1

**Goal:** A working app on both platforms that meets the brief.

**Kickoff prompt:**

> Read BRIEF.md, CLAUDE.md, and the approved docs from Phases 1 to 3. This is Phase 4. Run as the full team defined in CLAUDE.md.
> Build in this order, each with tests passing before moving on:
> 1. Weight entry and widget (the reliability requirement)
> 2. Food parser and one-screen meal entry, saved meals, aliases, recents, same as yesterday, barcode
> 3. Goals and daily calorie budget, including exercise add-back
> 4. Resistance training
> 5. Cardio with MET estimates
> 6. Summaries, micronutrient views
> 7. Health Connect and Apple Health sync (optional, off by default)
> 8. About, settings, units
> Run the speed-target integration tests at the end. Write docs/phase-4-summary.md, listing anything not finished, and stop.

**Gate:** All speed targets pass. Bart installs it on his Android phone and the iPhone.

---

## Phase 5: Dogfood

**Goal:** Bart uses only Daybook for 2 to 3 weeks.

**What happens:** Bart keeps a friction log in docs/friction-log.md (one line per annoyance or bug). No agent work until the log is handed over.

**Kickoff prompt (after the dogfood period):**

> Read docs/friction-log.md. This is Phase 5. For each item, reproduce it with a failing test where possible, then fix it. Group anything that changes the brief into a separate list for Bart instead of fixing it. Write docs/phase-5-summary.md and stop.

**Gate:** Bart signs off on the fixes.

---

## Phase 6: Release

**Goal:** Live on Google Play and the App Store, close together.

**Kickoff prompt:**

> Read BRIEF.md and CLAUDE.md. This is Phase 6. Prepare both store releases:
> 1. Store listings, screenshots made from the real app, short and long descriptions in plain language.
> 2. Privacy policy stating the app collects no data, hosted on freeplayinc.org.
> 3. Google Play health app declaration and data safety form; App Store privacy labels and HealthKit usage strings.
> 4. Signed release builds, Android via CI and iOS via the cloud macOS runner to TestFlight.
> 5. Add Daybook to the freeplayinc.org site.
> 6. List what Bart must do by hand (account sign-ins, submissions, review responses).
> Write docs/phase-6-summary.md and stop.

**Gate:** Bart submits to both stores.
