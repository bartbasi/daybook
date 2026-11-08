# CLAUDE.md: Rules for every agent on Daybook

Read BRIEF.md before doing anything. If this file and BRIEF.md disagree, stop and ask Bart.

## Models

- Agents use Sonnet 5.5 or Opus 5.5 only. Do not use Fable.
- Opus 5.5 for the lead/architect and reviewer roles. Sonnet 5.5 is fine for focused implementation and test work.

## Phase gates

- Work happens in phases defined in PHASES.md. Do only the current phase.
- At the end of each phase, stop, write a short summary in `docs/phase-N-summary.md`, and wait for Bart's approval. Do not start the next phase on your own.
- If something in the brief is unclear or looks wrong, ask. Do not guess silently. If there are two reasonable readings, list both.

## Promises in code

- No analytics, ads, tracking, crash reporting SDKs, or accounts. Ever.
- No network calls except Open Food Facts barcode lookups, food database download (if chosen), and Health Connect / Apple Health when the user enables it.
- No user data in logs.
- Every dependency must have a license compatible with the project license. Record each one in `docs/dependencies.md` with its license.

## Licensing and attribution

- Copy LICENSE and attribution wording from the WoodLogic repo (github.com/bartbasi/WoodLogic) verbatim. Developer: Bart Basi. Company: Play, Inc.
- Food data attribution (USDA FoodData Central, Open Food Facts under ODbL) goes in About and in `docs/data-sources.md`.
- Do not copy code, text, images, or data from MyFitnessPal or any other commercial app.

## How to work

- Simplest code that meets the brief. No features, settings, or abstractions that were not asked for.
- Touch only what the task needs. Do not refactor or restyle unrelated code.
- Every bug fix starts with a failing test that reproduces it.
- Weight entry, food logging, and data export/import must have automated tests before they are called done.
- Measure the speed targets in BRIEF.md with integration tests (tap counts) where possible.

## Team roles

- **Lead/Architect (Opus):** plans each phase, splits tasks, owns the data model and project structure, merges work.
- **Data/Nutrition (Sonnet):** food database, parser, nutrient math, calorie budget, MET calculations.
- **UI (Sonnet):** screens, widgets, home-screen widget, accessibility.
- **Test (Sonnet):** unit, widget, and integration tests; speed-target tests.
- **Reviewer (Opus):** reviews each change against BRIEF.md and this file before merge. Has not written the code it reviews.

## Writing

- Plain, human-sounding text in UI copy, docs, and commit messages. No em dashes or double hyphens.
