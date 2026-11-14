# Data sources

Checked 2026-11-08 against primary sources (official license pages, terms pages, and LICENSE files in repos). This is a plain reading of the licenses, not legal advice.

App code license for comparison: GPL-3.0 with additional attribution terms under GPL section 7, copied from WoodLogic.

## Summary

| Source | Used for | License | Usable? |
|---|---|---|---|
| USDA FoodData Central | Base food and nutrient data | Public domain, CC0 1.0 | Yes |
| Open Food Facts | Barcode lookups, packaged foods | ODbL 1.0 (database), DbCL 1.0 (contents), CC BY-SA (images) | Yes, with conditions |
| wger exercise data | Exercise library | Creative Commons, set per entry (mostly CC BY-SA 4.0, images CC BY-SA 3.0) | Yes, with conditions |
| 2024 Adult Compendium of Physical Activities | MET values for cardio | Free for commercial use, with conditions on the website | Yes, with conditions |
| FDA Daily Values | Default goals for nutrients the user has not set | US federal regulation, public domain | Yes |

Rejected: ExerciseDB (paid subscription license with a storage ban), free-exercise-db images (unknown origin).

---

## USDA FoodData Central

Primary sources:
- https://fdc.nal.usda.gov/api-guide/
- https://fdc.nal.usda.gov/download-datasets/

Terms, quoted from the API guide:
- "USDA FoodData Central data are in the public domain and they are not copyrighted."
- "They are published under CC0 1.0 Universal (CC0 1.0)."
- USDA asks that users credit FoodData Central as the source. This is a request, not a legal condition.

Suggested citation from USDA: "U.S. Department of Agriculture, Agricultural Research Service. FoodData Central, 2019. fdc.nal.usda.gov."

Datasets (latest releases on the download page):

| Dataset | Release | JSON zipped / unzipped | CSV zipped / unzipped | Notes |
|---|---|---|---|---|
| Foundation Foods | 10/2026 | 681 KB / 9 MB | 4.1 MB / 35 MB | Best quality, fewer foods |
| SR Legacy | 04/2018, frozen | 12.3 MB / 205 MB | 6.7 MB / 54 MB | Broad generic foods, full micronutrients |
| FNDDS 2021-2023 (Survey) | 10/2024 | 3.7 MB / 64 MB | 200 MB / 1.6 GB | Mixed dishes as eaten |
| Branded | 10/2026 | 187 MB / 3 GB | 432 MB / 3 GB | Too big to bundle; Open Food Facts covers barcodes |

Usable: yes.

Things to know:
- The API needs a data.gov key, and USDA says "Any API keys discovered online, such as those in a code repository, will be deactivated." An open-source app cannot ship a key, so Daybook should use the downloaded files, not the API. That also fits the no-network rule.
- Foundation Foods plus SR Legacy is the natural core set. Trimmed into SQLite they are small enough to bundle. FNDDS is worth considering for mixed dishes. The final choice belongs to Phase 2.

About screen text:
> Food data from USDA FoodData Central (U.S. Department of Agriculture, Agricultural Research Service, fdc.nal.usda.gov). Public domain (CC0 1.0).

---

## Open Food Facts

Primary sources:
- https://world.openfoodfacts.org/terms-of-use
- https://world.openfoodfacts.org/data
- https://openfoodfacts.github.io/openfoodfacts-server/api/
- https://opendatacommons.org/licenses/odbl/1-0/

Terms, quoted from the terms of use page:
- "The Open Food Facts database is available under the Open Database License."
- "Individual contents of the database are available under the Database Contents License."
- "Products images are available under the Creative Commons Attribution ShareAlike licence."
- Re-users "have to mention the licence and to attribute the authorship to Open Food Facts."
- "Derivative works must be shared under the same conditions."

API terms (from the API docs):
- Send a custom User-Agent in the form `AppName/Version (ContactEmail)`. This must be a project contact address, never anything about the user.
- Read limits: 15 product reads per minute per IP, 10 searches per minute per IP. One call per real user scan is the intended use.
- Reads need no account. Writes do, and Daybook will not write.
- Use the staging server (world.openfoodfacts.net) during development.
- OFF gives no guarantee that the data is accurate or complete. The app should let the user correct any value.

What ODbL means for Daybook:
- **Live lookups shown on screen** are "Produced Works" under ODbL 4.5(b). They need a notice that the data came from Open Food Facts under ODbL. A short line on the scanned product result plus the About entry covers it.
- **The on-device cache** of products the user scanned stays on their device and is never publicly used, so share-alike is not triggered. If an export file contains cached OFF fields, the export should carry an ODbL notice.
- **Bundling an OFF subset in the app** would make a Derivative Database that is conveyed publicly. We would then have to publish that subset under ODbL. Simplest path: do not bundle OFF data. If we ever do, publish the subset file and the script that builds it in the repo.
- **Compatibility with GPL-3.0:** ODbL 2.3(a) says it does not apply to the programs that use the database, and ODbL 4.5(a) treats the app plus data as a collective work. The data stays ODbL and in separate files, and the code stays GPL-3.0. No conflict.
- **App store DRM:** ODbL 4.7 allows store distribution with technical restrictions only if an unrestricted copy is also available. This only matters if we bundle OFF data, and publishing it on GitHub covers it.

Decisions (Bart, 2026-11-08):
- User-Agent: `Daybook/<version> (bartbasi@gmail.com)`.
- Do not fetch or show product images. They are CC BY-SA, may show trademarked packaging, and skipping them keeps network use to the minimum.
- Do not use the OFF logo, Nutri-Score, or NOVA badges. Text attribution only. (I found no published logo policy, so this is the cautious choice.)

Usable: yes, with the conditions above.

About screen text:
> Barcode product data from Open Food Facts (https://openfoodfacts.org), made available under the Open Database License (ODbL) v1.0 (https://opendatacommons.org/licenses/odbl/1-0/). Individual contents under the Database Contents License (DbCL) v1.0.

Short line on a scanned product:
> Data from Open Food Facts (ODbL)

---

## Exercise library: wger (recommended)

Primary sources:
- https://github.com/wger-project/wger (README license section)
- https://wger.de/api/v2/license/
- https://wger.de/api/v2/exerciseinfo/

Terms, quoted from the wger README:
- "Application Code: AGPL-3.0-or-later"
- "Exercise/Ingredient Data: Creative Commons (see individual entries)"
- "Documentation: CC-BY-SA-4.0"

Daybook uses only the data, so the AGPL code license does not apply. The data license is set on each entry. The license table lists CC BY-SA 3.0, CC BY 4.0, CC BY-SA 4.0, CC0 and ODbL. Entries sampled were CC BY-SA 4.0 with a named author. Images sampled were CC BY-SA 3.0, many by Everkinetic.

What it has: about 950 exercises in the live database, about 380 images. Fields include category, primary and secondary muscles, equipment, a description, aliases, variations, and license author per entry. Not every exercise has an image.

What was fetched (task 4.1, 2026-11-13, by `tools/build_exercise_data.py`, from https://wger.de/api/v2/exerciseinfo/ and /license/):
- 967 exercises, all with English text, a name and a license. 42 were left out (see below), so 925 are in the asset.
- License of the English text, as wger names them, in the asset: CC-BY-SA 4: 777, CC-BY-SA 3: 128, CC0: 20. No other license appeared. wger lists CC0 as "Creative Commons Public Domain 1.0"; it is CC0 1.0 Universal, the Public Domain Dedication.
- 767 have primary muscles, 716 have equipment, 88 have aliases, 33 have an empty description.
- Credits: 862 name an author as wger gives it. 20 entries had an email address as author and are shown as "wger.de contributor" (40 author strings, because wger lists each one twice). 43 have no author at either level (the English text or the exercise) and are also credited to "wger.de contributor". When the English text has no author, the exercise's own author is used.
- Left out, each by a named rule or id list in the tool: 38 entries whose name ends with "(Custom)" (ids 2699 to 2724 and 2749 to 2760, template copies of existing exercises); 2645 (made by a routine importer), 1949 ("Limber 11" is a routine), 2452 and 1702 (Spanish names).
- Descriptions left empty: 202, 204, 260, 445, 580, 599, 655, 688 and 1925, because wger's own record says the text came from a commercial site or magazine (nothing is copied from commercial sources); and 205, which was only a full stop. The name, muscles, equipment, license and credit of these stay.
- The build prints any description that says "taken from" or "copied from". On this fetch only 1925 matched.
- The result is `assets/exercises/wger_exercises.json`, about 670 KB, no images or videos. Its README lists the licenses and the changes made (HTML turned into plain text, English only).

Compatibility with GPL-3.0:** ODbL 2.3(a) says it does not apply to the programs that use the database, and ODbL 4.5(a) treats the app plus data as a collective work. The data stays ODbL and in separate files, and the code stays GPL-3.0. No conflict.
- **App store DRM:** ODbL 4.7 allows store distribution with technical restrictions only if an unrestricted copy is also available. This only matters if we bundle OFF data, and publishing it on GitHub covers it.

Decisions (Bart, 2026-11-08):
- User-Agent: `Daybook/<version> (bartbasi@gmail.com)`.
- Do not fetch or show product images. They are CC BY-SA, may show trademarked packaging, and skipping them keeps network use to the minimum.
- Do not use the OFF logo, Nutri-Score, or NOVA badges. Text attribution only. (I found no published logo policy, so this is the cautious choice.)

Usable: yes, with the conditions above.

About screen text:
> Barcode product data from Open Food Facts (https://openfoodfacts.org), made available under the Open Database License (ODbL) v1.0 (https://opendatacommons.org/licenses/odbl/1-0/). Individual contents under the Database Contents License (DbCL) v1.0.

Short line on a scanned product:
> Data from Open Food Facts (ODbL)

---

## Exercise library: wger (recommended)

Primary sources:
- https://github.com/wger-project/wger (README license section)
- https://wger.de/api/v2/license/
- https://wger.de/api/v2/exerciseinfo/

Terms, quoted from the wger README:
- "Application Code: AGPL-3.0-or-later"
- "Exercise/Ingredient Data: Creative Commons (see individual entries)"
- "Documentation: CC-BY-SA-4.0"

Daybook uses only the data, so the AGPL code license does not apply. The data license is set on each entry. The license table lists CC BY-SA 3.0, CC BY 4.0, CC BY-SA 4.0, CC0 and ODbL. Entries sampled were CC BY-SA 4.0 with a named author. Images sampled were CC BY-SA 3.0, many by Everkinetic.

What it has: about 950 exercises in the live database, about 380 images. Fields include category, primary and secondary muscles, equipment, a description, aliases, variations, and license author per entry. Not every exercise has an image.

What was fetched (task 4.1, 2026-11-13, by `tools/build_exercise_data.py`, from https://wger.de/api/v2/exerciseinfo/ and /license/):
- 967 exercises, all with English text and a name. None were dropped.
- License of the English text, as wger names them: CC-BY-SA 4: 819, CC-BY-SA 3: 128, CC0: 20. No other license appeared.
- 807 have primary muscles, 739 have equipment, 88 have aliases, 23 have an empty description.
- 20 entries had an email address as author. Each is shown as "wger.de contributor" (40 author strings, because wger lists each one twice). 77 more entries have no author recorded and are also credited to "wger.de contributor".
- The result is `assets/exercises/wger_exercises.json`, about 700 KB, no images or videos. Its README lists the licenses and the changes made (HTML turned into plain text, English only).

Compatibility with GPL-3.0:
- CC BY-SA 4.0 can be relicensed one way into GPLv3, but CC BY-SA 3.0 cannot.
- Neither matters if we ship the exercise data as separate asset files under their own CC licenses rather than mixing them into code. That is the plan.

Conditions:
- Credit each entry: author, license, and a link. Note when we edit the text.
- If we change the exercise files, our changed versions are CC BY-SA too. Publish them in the repo.
- Bundle a snapshot at build time. No network calls to wger from the app (CLAUDE.md allows none).

Decision (Bart, 2026-11-08): when a wger `license_author` value is an email address, do not show it. Credit the entry as "wger.de contributor" with a link to that exercise on wger.de.

Usable: yes, with conditions.

Changed in Phase 4, for the owner to confirm at the gate: the approved text below has two additions, "and CC0" in the license list and the sentence "Descriptions were changed from HTML to plain text." (CC BY-SA asks us to say we changed the material). The Everkinetic sentence is dropped (open question 7). Also, the exercise list leaves out some entries and descriptions, as listed under "What was fetched" above: template copies named "(Custom)", four entries that are not real English exercises, and nine descriptions wger says came from commercial sources.

About screen text:
> Exercise data from the wger project (https://wger.de), by wger.de contributors, licensed under Creative Commons (CC BY-SA 4.0, CC BY-SA 3.0 and CC0; see each exercise for author and license). Descriptions were changed from HTML to plain text.

Each exercise detail screen also shows its own author and license, for example "Text by wger.de contributor, CC BY-SA 4.0" with a link to the exercise on wger.de. The data file keeps wger's own license names ("CC-BY-SA 4", "CC-BY-SA 3", "CC0") and the license URL; the screen shows the license by its usual name ("CC BY-SA 4.0", "CC BY-SA 3.0", "CC0 1.0"), linked to that URL. Two authors read "A and B"; three or more read "A, B, and C".

### Other exercise lists checked

| List | License | Verdict |
|---|---|---|
| yuhonas/free-exercise-db (https://github.com/yuhonas/free-exercise-db) | Unlicense (public domain) for the repo | Text and fields usable. Images not usable: the maintainer said in issue #2, "I actually have no idea where the images are from or if they are royalty free." Where the upstream text came from is also not established. Could fill gaps in names, muscles and equipment. |
| ExerciseDB (https://github.com/ExerciseDB/exercisedb-api) | AGPL code; data under a paid, revocable subscription license with a "Strict Storage Prohibition" | Not usable. (Terms seen only in part.) |
| exercemus/exercises | MIT code, mixed data from wger and exercises.json | Inherits the same origin question. Not recommended. |
| everkinetic/data | CC BY-SA 4.0 | Small and inactive; its illustrations are already in wger. |

---

## MET values: 2024 Adult Compendium of Physical Activities

Primary sources:
- https://pacompendium.com/
- https://pacompendium.com/adult-compendium/
- Article: https://pmc.ncbi.nlm.nih.gov/articles/PMC10818145/

Terms, quoted from pacompendium.com:
- "The Adult, Older Adult, and Wheelchair Compendia are free to use for commercial purposes."
- "Please do not change MET values or combine activities with different MET levels."
- "Please cite the Compendium website or publication(s)."
- Questions about use go to compendiumpa@gmail.com.

There is no formal license name. The journal article itself is under CC BY-NC-ND (Elsevier), so values should come from the website or its downloadable PDF, under the website's permission, not from the article's tables.

Content: 1,114 activities under 22 headings, for adults 19 to 59.

Conditions:
- Cite the Compendium.
- Use MET values exactly as published.
- Recommended: email compendiumpa@gmail.com describing Daybook (free, open source, in app stores, values shown unchanged with citation) and keep the reply in this file. This is outward-facing, so Bart sends it.

Decision (Bart, 2026-11-08): use the strict reading of "do not combine activities with different MET levels." No blending or interpolation. If a run is at 6.3 mph, use the nearest listed activity (6 mph). The user can override the calorie estimate, as the brief already requires.

Permission email: Bart sends it to compendiumpa@gmail.com (draft in phase-1-summary.md). Paste the reply here when it arrives.

Alternatives checked:
- 2011 Compendium (Ainsworth et al., Med Sci Sports Exerc 2011;43(8):1575-81): no clearer terms found, and the site's commercial-use line names only the 2024 compendia.
- CDC intensity table: US government work, but old and mostly gives intensity bands, not per-activity MET values. Not good enough.

Usable: yes, with conditions.

About screen text:
> MET values from the 2024 Adult Compendium of Physical Activities (https://pacompendium.com). Herrmann SD, Willis EA, Ainsworth BE, Barreira TV, Hastert M, Kracht CL, Schuna JM Jr, Cai Z, Quan M, Tudor-Locke C, Whitt-Glover MC, Jacobs DR Jr. 2024 Adult Compendium of Physical Activities: A third update of the energy costs of human activities. J Sport Health Sci. 2024;13(1):6-12. doi:10.1016/j.jshs.2023.10.010.

---

## FDA Daily Values

Primary source: 21 CFR 101.9(c)(8)(iv) (Reference Daily Intakes for vitamins and minerals) and (c)(9) (Daily Reference Values), as set by the 2016 Nutrition Facts label final rule, at https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9

Used for: the default goal of each tracked nutrient that has a Daily Value, for adults and children 4 years and over. The values are in `Nutrients.dailyValues` in `lib/data/nutrients.dart`. Total sugars and trans fat have no Daily Value, so they get no default goal.

License: a federal regulation is a US government work and is not copyrighted.

---

## Not yet verified

- FNDDS and Branded citation formats (only the general FDC citation and the Foundation and SR Legacy ones were found).
- Full ExerciseDB terms text (rejected anyway).
- Whether Open Food Facts has a published logo or trademark policy.
- Reuse terms for the 2011 Compendium.
