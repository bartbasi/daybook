# Daybook. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
"""Builds assets/exercises/wger_exercises.json from wger's public exercise data.

Usage: python -I tools/build_exercise_data.py [--cache DIR] [--out-dir DIR] [--refresh]

Source: the wger API (https://wger.de/api/v2/exerciseinfo/ and /license/).
The raw answers are downloaded once into the cache folder (default
build/wger-cache/, git-ignored) and the asset is built from that cache, so the
same cache always gives the same file. Delete the cache or pass --refresh to
fetch again. The app itself never calls wger. Only the Python standard
library is used.

What is kept, per exercise that has English text: the wger id, the English
name and aliases, the category, primary and secondary muscles (English names),
equipment, the description as plain text, the license of the English text
(name, full name, URL), the author list, and the link to the exercise on
wger.de. No images and no videos. Any author that is or contains an email
address is shown as "wger.de contributor".
"""
import argparse
import datetime
import html
import html.parser
import json
import os
import re
import sys
import time
import urllib.request

API = "https://wger.de/api/v2/"
USER_AGENT = "exercise-data-builder/1.0"
ENGLISH = 2  # wger's language id for English
PAGE = 100
PAUSE_SECONDS = 1.0
CONTRIBUTOR = "wger.de contributor"
EXERCISE_URL = "https://wger.de/en/exercise/%d/view/"

EMAIL = re.compile(r"[^\s@<>]+@[^\s@<>]+", re.I)
LEFTOVER_TAG = re.compile(r"</?[A-Za-z!][^<>]*>")


def get_json(url):
    req = urllib.request.Request(
        url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def fetch(cache, refresh=False):
    """Returns (exercises, licenses, fetched date), downloading if needed."""
    raw = os.path.join(cache, "exerciseinfo.json")
    if refresh or not os.path.exists(raw):
        os.makedirs(cache, exist_ok=True)
        print("downloading from wger.de", file=sys.stderr)
        results = []
        url = "%sexerciseinfo/?language=%d&limit=%d" % (API, ENGLISH, PAGE)
        while url:
            page = get_json(url)
            results.extend(page["results"])
            url = page["next"]
            if url:
                time.sleep(PAUSE_SECONDS)
        licenses = get_json(API + "license/")["results"]
        today = datetime.date.today().isoformat()
        for name, data in (("licenses.json", licenses),
                           ("exerciseinfo.json", results)):
            with open(os.path.join(cache, name), "w", encoding="utf-8",
                      newline="\n") as f:
                json.dump(data, f, ensure_ascii=False)
        with open(os.path.join(cache, "fetched.txt"), "w") as f:
            f.write(today + "\n")
    with open(raw, encoding="utf-8") as f:
        exercises = json.load(f)
    with open(os.path.join(cache, "licenses.json"), encoding="utf-8") as f:
        licenses = json.load(f)
    with open(os.path.join(cache, "fetched.txt")) as f:
        fetched = f.read().strip()
    return exercises, licenses, fetched


class _Text(html.parser.HTMLParser):
    """Collects the text of an HTML fragment, one block per line."""

    BLOCKS = {"p", "div", "br", "li", "ul", "ol", "tr", "table", "blockquote",
              "h1", "h2", "h3", "h4", "h5", "h6", "pre", "hr"}
    SKIP = {"script", "style"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out = []
        self.skip = 0
        self.lists = []  # [is ordered, next number]

    def handle_starttag(self, tag, attrs):
        if tag in self.SKIP:
            self.skip += 1
        if tag in ("ul", "ol"):
            self.lists.append([tag == "ol", 1])
        if tag in self.BLOCKS:
            self.out.append("\n")
        if tag == "li" and not self.skip:
            if self.lists and self.lists[-1][0]:
                self.out.append("%d. " % self.lists[-1][1])
                self.lists[-1][1] += 1
            else:
                self.out.append("- ")

    def handle_endtag(self, tag):
        if tag in self.SKIP and self.skip:
            self.skip -= 1
        if tag in ("ul", "ol") and self.lists:
            self.lists.pop()
        if tag in self.BLOCKS:
            self.out.append("\n")

    def handle_data(self, data):
        if not self.skip:
            self.out.append(data)


def plain_text(source):
    """HTML to plain text: blocks become lines, entities are decoded, and no
    tags, scripts, links or email addresses are left."""
    parser = _Text()
    parser.feed(source or "")
    parser.close()
    text = "".join(parser.out).replace("\xa0", " ")
    # Entities such as &lt;b&gt; decode to tag-looking text. Remove that too.
    text = EMAIL.sub("", LEFTOVER_TAG.sub("", html.unescape(text)))
    lines = [re.sub(r"[ \t]+", " ", ln).strip() for ln in text.splitlines()]
    return "\n".join(ln for ln in lines if ln)


def clean_line(text):
    """A one-line field (name, alias, muscle): no tags, no email address."""
    text = LEFTOVER_TAG.sub("", html.unescape(text or ""))
    text = EMAIL.sub("", text)
    return re.sub(r"\s+", " ", text).strip()


def credit(author):
    """The author as shown: an email address, or a string holding one, is
    replaced as a whole by 'wger.de contributor'."""
    author = re.sub(r"\s+", " ", author or "").strip()
    if not author:
        return ""
    return CONTRIBUTOR if "@" in author or EMAIL.search(author) else author


def build_entries(exercises, licenses):
    """Returns (entries sorted by id, stats)."""
    by_id = {lic["id"]: lic for lic in licenses}
    stats = {"seen": 0, "no_english": 0, "no_name": 0, "no_license": 0,
             "email_authors": 0, "email_entries": 0, "no_author": 0}
    entries = []
    for ex in exercises:
        stats["seen"] += 1
        english = [t for t in ex.get("translations", [])
                   if t.get("language") == ENGLISH]
        if not english:
            stats["no_english"] += 1
            continue
        tr = english[0]
        name = clean_line(tr.get("name"))
        if not name:
            stats["no_name"] += 1
            continue
        lic = by_id.get(tr.get("license"))
        if lic is None:
            stats["no_license"] += 1
            continue
        raw_authors = list(tr.get("author_history") or [])
        if tr.get("license_author"):
            raw_authors.append(tr["license_author"])
        authors = []
        replaced = 0
        for a in raw_authors:
            shown = credit(a)
            if shown == CONTRIBUTOR and a.strip() != CONTRIBUTOR:
                replaced += 1
            if shown and shown not in authors:
                authors.append(shown)
        stats["email_authors"] += replaced
        stats["email_entries"] += 1 if replaced else 0
        if not authors:
            stats["no_author"] += 1
            authors = [CONTRIBUTOR]
        aliases = []
        for a in tr.get("aliases") or []:
            a = clean_line(a.get("alias") if isinstance(a, dict) else a)
            if a and a != name and a not in aliases:
                aliases.append(a)
        entries.append({
            "id": ex["id"],
            "name": name,
            "aliases": aliases,
            "category": clean_line((ex.get("category") or {}).get("name")),
            "primary_muscles": _names(ex.get("muscles"), "name_en", "name"),
            "secondary_muscles": _names(ex.get("muscles_secondary"),
                                        "name_en", "name"),
            "equipment": _names(ex.get("equipment"), "name"),
            "description": plain_text(tr.get("description")),
            "license": lic["short_name"].strip(),
            "license_full": lic["full_name"].strip(),
            "license_url": lic["url"].strip(),
            "authors": authors,
            "url": EXERCISE_URL % ex["id"],
        })
    entries.sort(key=lambda e: e["id"])
    return entries, stats


def _names(items, *keys):
    out = []
    for item in items or []:
        for k in keys:
            if item.get(k):
                n = clean_line(item[k])
                if n and n not in out:
                    out.append(n)
                break
    return sorted(out)


def dump(entries):
    """One entry per line, keys sorted, UTF-8, LF, no timestamps."""
    lines = [json.dumps(e, ensure_ascii=False, sort_keys=True,
                        separators=(",", ":")) for e in entries]
    return "[\n" + ",\n".join(lines) + "\n]\n"


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default=os.path.join(root, "build", "wger-cache"))
    ap.add_argument("--out-dir", default=os.path.join(root, "assets", "exercises"))
    ap.add_argument("--refresh", action="store_true")
    args = ap.parse_args()

    exercises, licenses, fetched = fetch(args.cache, args.refresh)
    entries, stats = build_entries(exercises, licenses)
    os.makedirs(args.out_dir, exist_ok=True)
    path = os.path.join(args.out_dir, "wger_exercises.json")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(dump(entries))

    counts = {}
    for e in entries:
        counts[e["license"]] = counts.get(e["license"], 0) + 1
    print("fetched:", fetched)
    print("exercises seen:", stats["seen"], "kept:", len(entries))
    print("dropped:", {k: stats[k] for k in
                       ("no_english", "no_name", "no_license")})
    print("licenses:", counts)
    print("author strings replaced by", CONTRIBUTOR + ":",
          stats["email_authors"], "in", stats["email_entries"], "entries")
    print("entries with no author recorded, credited as", CONTRIBUTOR + ":",
          stats["no_author"])
    print("bytes:", os.path.getsize(path))


if __name__ == "__main__":
    main()
