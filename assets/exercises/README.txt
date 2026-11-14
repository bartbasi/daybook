wger exercise data for Daybook

What this is
  wger_exercises.json is the exercise library the app bundles: 967 exercises
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
    CC-BY-SA 4 (Creative Commons Attribution Share Alike 4): 819 entries
    CC-BY-SA 3 (Creative Commons Attribution Share Alike 3): 128 entries
    CC0 (Creative Commons Public Domain 1.0): 20 entries
  This file is shared under those licenses, each entry under its own. It is a
  separate data file and is not part of Daybook's program code. Credit the
  authors of an entry when you show it.

Changes made to the wger data
  - Descriptions had HTML. It is turned into plain text: paragraphs and list
    items become lines, entities are decoded, tags are removed.
  - Only the English text of each exercise is kept.
  - Muscles use wger's English names.
  - An author that is or contains an email address is written as
    "wger.de contributor". 20 entries had one. 77 entries have no author
    recorded in wger and are credited to "wger.de contributor" too.
  - Fields not listed above (images, videos, other languages, notes, dates)
    are left out.

How to rebuild
  python -I tools/build_exercise_data.py
  The raw answers are cached in build/wger-cache/ (not committed), so the same
  cache always gives the same file. Use --refresh to fetch again.
  python -I -m unittest discover -s tools runs the tests.
