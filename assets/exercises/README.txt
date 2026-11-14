wger exercise data for Daybook

What this is
  wger_exercises.json is the exercise library the app bundles: 925 exercises
  with English text, taken from the wger project (https://wger.de). One entry
  per line, sorted by wger id.

Where it came from
  The wger API: https://wger.de/api/v2/exerciseinfo/ (language English) and
  https://wger.de/api/v2/license/. Fetched on 2026-11-13. The app itself never
  calls wger. This file is a snapshot, and the committed file is the pin.

What each entry has
  id, name, aliases, category, primary_muscles, secondary_muscles, equipment,
  description (plain text), license (wger's short name), license_full,
  license_url, authors, and url (the exercise's page on wger.de).
  No images and no videos are included.

Licenses
  The data is Creative Commons, set per entry by wger. In this file:
    CC-BY-SA 4 (Creative Commons Attribution Share Alike 4): 777 entries
    CC-BY-SA 3 (Creative Commons Attribution Share Alike 3): 128 entries
    CC0 (CC0 1.0 Universal, Public Domain Dedication, which wger lists as
      "Creative Commons Public Domain 1.0"): 20 entries
  The license names are wger's own labels. The license URLs for
  creativecommons.org are written with https. This file is shared under those
  licenses, each entry under its own. It is a separate data file and is not
  part of Daybook's program code. Credit the authors of an entry when you show
  it.

Changes made to the wger data
  - Descriptions had HTML. It is turned into plain text: paragraphs and list
    items become lines, entities are decoded, tags are removed. Zero width
    characters are removed from all text.
  - Only the English text of each exercise is kept.
  - Muscles use wger's English names.
  - Authors: the author list of the English text is used. When it has none,
    the exercise's own author list is used. An author that is or contains an
    email address is written as "wger.de contributor". 20 entries had one.
    43 entries have no author at either level in wger and are credited to
    "wger.de contributor" too. Every other credit is as wger gives it.
  - Fields not listed above (images, videos, other languages, notes, dates)
    are left out.

Left out, and why
  - Descriptions of 202, 204, 260, 445, 580, 599, 655, 688 and 1925. wger's own
    record says that text came from a commercial site or magazine (for
    example 1925 ends with "Description taken from MuscleWiki"). The name,
    muscles, equipment, license and credit of these entries are kept. The
    reason for each id is in tools/build_exercise_data.py.
  - Any description with no letters or digits (205 was just a full stop) is
    left empty.
  - 38 entries whose name ends with "(Custom)" (ids 2699 to 2724 and 2749 to
    2760). They are copies of existing exercises made from a template.
  - 2645 (its description says a routine importer made it), 1949 ("Limber 11"
    is a routine, not an exercise), 2452 and 1702 (Spanish names, and the
    text of 2452 is about a different exercise).
  - The build prints every description that says "taken from" or "copied
    from", so a new fetch shows new cases. Those are not removed by that rule.

How to rebuild
  python -I tools/build_exercise_data.py
  The raw answers are cached in build/wger-cache/ (not committed), so the same
  cache always gives the same file. Use --refresh to fetch again. The fetch
  stops after 50 pages and refuses any link that leaves the wger API.
  python -I -m unittest discover -s tools runs the tests.
