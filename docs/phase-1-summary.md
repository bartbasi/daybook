# Phase 1 summary

Docs only. No app code was written. Details are in [survey.md](survey.md) and [data-sources.md](data-sources.md).

## What was done

1. Surveyed 7 open-source trackers in depth (OpenNutriTracker, Waistline, wger, Energize, Flex, Liftosaur, FitoTrack) and a few more briefly.
2. Checked the license and terms for USDA FoodData Central, Open Food Facts, exercise libraries, and MET sources against primary sources.
3. Wrote a MyFitnessPal feature inventory from public information, marked Free or Premium.
4. Found out what the MyFitnessPal export contains and whether import is possible.

## Key findings

- **OpenNutriTracker already has free-text, multi-item meal entry** (v2.2.0, September 2026). It is Flutter and GPL-3.0, the same as Daybook. Its parser runs on the device, but matching each line needs an online search, it sends lines to a separate review screen, and it does not read number words. Daybook can still stand out: fully offline matching, live lines on the same screen, household units, learning from corrections, and lifting, cardio and weight in one app. See survey.md, "How Daybook differs".
- **All four data sources are usable.**
  - USDA FDC is public domain.
  - Open Food Facts is ODbL. That needs attribution, and share-alike applies only if we bundle OFF data.
  - wger exercise data is CC BY-SA, with credit for each entry.
  - The 2024 Compendium MET values are free for commercial use if cited and not altered.
- **Exercise library recommendation: wger data**, shipped as separate data files under their own CC licenses. ExerciseDB is not usable. free-exercise-db text is public domain, but its images are of unknown origin and must not be used.
- **Food data recommendation for Phase 2:** use the downloaded USDA files (Foundation Foods plus SR Legacy, maybe FNDDS), not the USDA API. The API needs a key, and keys published in a repo get deactivated.
- **MyFitnessPal export:** Premium only. It gives meal totals per day, not individual foods, plus weight, measurements and exercise. Import is possible for weight, meal totals and exercise. Individual foods, recipes, saved meals and goals cannot be imported.
- MyFitnessPal does not appear to track several nutrients the brief requires (added sugar, magnesium, zinc, vitamins D, E, K, B6, B12, folate). Unverified, because there is no official full list.

## Questions for Bart (answered, see Decisions)

1. **OpenNutriTracker overlap.** Two reasonable readings of the brief:
   - (a) Build Daybook as planned. ONT is a good reference, but it is not offline, does not include lifting, and uses crash reporting.
   - (b) Look at contributing the missing pieces to ONT instead.

   The brief reads as (a). Please confirm.
2. **GPL-3.0 and the Apple App Store.** GPL-3.0 code and App Store terms are known to conflict (the 2011 VLC case). Play, Inc. owns all the code, so it can publish anyway. But if outside contributors send code, we would need their permission for App Store distribution. Options:
   - add an App Store exception to the section 7 terms;
   - ask contributors to sign an agreement;
   - accept outside contributions only with that permission.

   Has WoodLogic dealt with this already? I did not change any license terms.
3. **Contact email for the Open Food Facts User-Agent.** OFF asks every app to identify itself with a contact address (for example `Daybook/1.0 (address)`). Which address should we use? It is also the "Send feedback" address in About.
4. **wger authors listed as email addresses.** Some wger entries credit an author by email. Options:
   - credit them as "wger.de contributor" with a link to the entry;
   - leave those exercises out.

   I recommend the first.
5. **MET values and "do not combine activities".** Two readings:
   - (a) Strict: snap to the nearest listed activity, no interpolation.
   - (b) Loose: on-the-fly estimates between listed speeds are fine.

   I recommend (a). The user can override the estimate anyway. I also suggest you email compendiumpa@gmail.com to confirm in writing that Daybook's use is fine. I can draft the email. I did not send anything.
6. **Open Food Facts images.** I recommend not showing product photos at all: less licensing work and fewer network calls. OK?
7. **A real MyFitnessPal export.** The exact column names, date format and units are not public. If you have Premium, or know someone who does, a sample export with a week of data would let Phase 2 or 4 build the importer against real files. Without one, I suggest we defer MFP import and say so in the Phase 4 list of unfinished items.

## Decisions (Bart, 2026-11-08)

1. Build Daybook as planned. OpenNutriTracker is a reference only.
2. GPL-3.0 and the App Store: Bart says it should be fine. No license change.
3. Contact email: bartbasi@gmail.com, for the Open Food Facts User-Agent and Send feedback.
4. wger authors listed as email addresses: credit as "wger.de contributor" with a link to the entry.
5. MET values: strict reading. Nearest listed activity, no interpolation. Bart emails the Compendium team (draft below).
6. Open Food Facts product photos: not shown.
7. MyFitnessPal import: skipped for now.

### Draft email to the Compendium team

To: compendiumpa@gmail.com
Subject: Permission to use 2024 Adult Compendium MET values in a free app

> Hello,
>
> I am building Daybook, a free, open-source fitness and nutrition tracker for Android and iOS, published by Play, Inc. It has no ads, no paid features, and collects no user data.
>
> We would like to use MET values from the 2024 Adult Compendium of Physical Activities to estimate calories burned during cardio. We plan to:
>
> - use the values exactly as published, without changing them or combining activities;
> - cite the Compendium and the 2024 publication in the app's About screen and in our source repository;
> - let users override the estimate.
>
> Your website says the Compendium is free for commercial use. Could you confirm this use is fine with you?
>
> Thank you,
> Bart Basi
> Play, Inc.
> bartbasi@gmail.com

## Not verified

- MyFitnessPal tier placement, from search summaries because the help center blocks automated reads.
- MyFitnessPal export headers, date format and units.
- Tap counts for OpenNutriTracker's new text flow and for weight entry in most apps.
- FNDDS and Branded citation formats.
- OFF logo policy.
- 2011 Compendium terms.

## Gate

Phase 1 is done. Waiting for Bart to approve the survey and confirm the data sources before starting Phase 2.
