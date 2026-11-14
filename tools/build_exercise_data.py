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
MAX_PAGES = 50
PAUSE_SECONDS = 1.0
CONTRIBUTOR = "wger.de contributor"
EXERCISE_URL = "https://wger.de/en/exercise/%d/view/"

# Descriptions left out (the name, muscles, equipment, license and credit stay
# as wger supplies them). wger's own record says this text came from a
# commercial source, and nothing is copied from commercial apps or sites.
DESCRIPTION_LEFT_OUT = {
    1925: "ends with 'Description taken from MuscleWiki'",
    202: "author field names exrx.net",
    204: "author field names ExRx",
    260: "author field names realsimple.com",
    580: "author field names bodybuilding.com",
    655: "author field names bodybuilding.com",
    688: "author field names carinatum.com",
    445: "author field names Mens Fitness",
    599: "author field names Mens Fitness",
}

# Entries left out of the asset, by id, with the reason.
ENTRY_LEFT_OUT = {
    2645: "description says it was made by a routine importer",
    1949: "'Limber 11' is a routine, not an exercise",
    2452: "Spanish name, and the description is about a different exercise",
    1702: "Spanish name",
}
# Entries whose name ends with this are left out too: copies of existing
# exercises made from a template.
CUSTOM_SUFFIX = "(Custom)"

# Descriptions that say where they came from, reported by the build so a new
# refresh shows new cases. These are not dropped by this rule.
TAKEN_FROM = re.compile(r"\b(?:taken|copied) from\s+[^\n]{0,40}", re.I)

ZERO_WIDTH = re.compile("[\u200b\u200c\u200d\ufeff]")
HAS_TEXT = re.compile(r"[^\W_]")

EMAIL = re.compile(r"[^\s@<>]+@[^\s@<>]+", re.I)
LEFTOVER_TAG = re.compile(r"</?[A-Za-z!][^<>]*>")


def get_json(url):
    req = urllib.request.Request(
        url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def fetch(cache, refresh=False, get=get_json, pause=PAUSE_SECONDS):
    """Returns (exercises, licenses, fetched date), downloading if needed.
    The download follows at most MAX_PAGES pages and only links that stay on
    the wger API; otherwise it raises FetchError and writes nothing."""
    raw = os.path.join(cache, "exerciseinfo.json")
    if refresh or not os.path.exists(raw):
        os.makedirs(cache, exist_ok=True)
        print("downloading from wger.de", file=sys.stderr)
        results = []
        url = "%sexerciseinfo/?language=%d&limit=%d" % (API, ENGLISH, PAGE)
        pages = 0
        while url:
            pages += 1
            if pages > MAX_PAGES:
                raise FetchError("more than %d pages, stopping" % MAX_PAGES)
            if not url.startswith(API):
                raise FetchError("the next page is not on the wger API, stopping")
            page = get(url)
            results.extend(page["results"])
            url = page["next"]
            if url:
                time.sleep(pause)
        licenses = get(API + "license/")["results"]
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


class FetchError(Exception):
    pass


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
        self.marker = False  # a list marker was just written

    def _break(self):
        # No line break straight after a marker, so "1." keeps its text.
        if not self.marker:
            self.out.append("\n")

    def handle_starttag(self, tag, attrs):
        if tag in self.SKIP:
            self.skip += 1
        if tag in ("ul", "ol"):
            self.lists.append([tag == "ol", 1])
        if tag in self.BLOCKS:
            self._break()
        if tag == "li" and not self.skip:
            if self.lists and self.lists[-1][0]:
                self.out.append("%d. " % self.lists[-1][1])
                self.lists[-1][1] += 1
            else:
                self.out.append("- ")
            self.marker = True

    def handle_endtag(self, tag):
        if tag in self.SKIP and self.skip:
            self.skip -= 1
        if tag in ("ul", "ol") and self.lists:
            self.lists.pop()
        if tag in self.BLOCKS:
            self._break()

    def handle_data(self, data):
        if self.skip:
            return
        if self.marker:
            data = data.lstrip()
            if not data:
                return
            self.marker = False
        self.out.append(data)


def plain_text(source):
    """HTML to plain text: blocks become lines, entities are decoded, and no
    tags, scripts, links or email addresses are left."""
    parser = _Text()
    parser.feed(source or "")
    parser.close()
    text = ZERO_WIDTH.sub("", "".join(parser.out)).replace("\xa0", " ")
    # Entities such as &lt;b&gt; decode to tag-looking text. Remove that too.
    text = EMAIL.sub("", LEFTOVER_TAG.sub("", html.unescape(text)))
    lines = [re.sub(r"[ \t]+", " ", ln).strip() for ln in text.splitlines()]
    return "\n".join(ln for ln in lines if ln)


def clean_line(text):
    """A one-line field (name, alias, muscle): no tags, no email address."""
    text = ZERO_WIDTH.sub("", LEFTOVER_TAG.sub("", html.unescape(text or "")))
    text = EMAIL.sub("", text)
    return re.sub(r"\s+", " ", text).strip()


def credit(author):
    """The author as shown: an email address, or a string holding one, is
    replaced as a whole by 'wger.de contributor'."""
    author = re.sub(r"\s+", " ", ZERO_WIDTH.sub("", author or "")).strip()
    if not author:
        return ""
    return CONTRIBUTOR if "@" in author or EMAIL.search(author) else author


def https_url(url):
    """creativecommons.org links are written with https. Only the URL changes."""
    url = url.strip()
    if url.startswith("http://creativecommons.org/"):
        url = "https://" + url[len("http://"):]
    return url


def _author_list(*sources):
    """Authors from the first source that has any, as (shown, email count)."""
    for src in sources:
        raw = list(src.get("author_history") or [])
        if src.get("license_author"):
            raw.append(src["license_author"])
        shown, replaced = [], 0
        for a in raw:
            c = credit(a)
            if c == CONTRIBUTOR and a.strip() != CONTRIBUTOR:
                replaced += 1
            if c and c not in shown:
                shown.append(c)
        if shown:
            return shown, replaced
    return [], 0


def build_entries(exercises, licenses):
    """Returns (entries sorted by id, stats)."""
    by_id = {lic["id"]: lic for lic in licenses}
    stats = {"seen": 0, "no_english": 0, "no_name": 0, "no_license": 0,
             "email_authors": 0, "email_entries": 0, "no_author": 0,
             "named": 0, "left_out": [], "custom": [], "emptied": [],
             "empty_text": [], "taken_from": []}
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
        if ex["id"] in ENTRY_LEFT_OUT:
            stats["left_out"].append(ex["id"])
            continue
        if name.endswith(CUSTOM_SUFFIX):
            stats["custom"].append(ex["id"])
            continue
        # The English text's authors first; when it has none, the exercise's.
        authors, replaced = _author_list(tr, ex)
        stats["email_authors"] += replaced
        stats["email_entries"] += 1 if replaced else 0
        if not authors:
            stats["no_author"] += 1
            authors = [CONTRIBUTOR]
        elif authors != [CONTRIBUTOR]:
            stats["named"] += 1
        description = plain_text(tr.get("description"))
        found = TAKEN_FROM.search(description)
        if found:
            stats["taken_from"].append((ex["id"], found.group(0).strip(),
                                        ex["id"] in DESCRIPTION_LEFT_OUT))
        if ex["id"] in DESCRIPTION_LEFT_OUT:
            stats["emptied"].append(ex["id"])
            description = ""
        elif description and not HAS_TEXT.search(description):
            stats["empty_text"].append(ex["id"])
            description = ""
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
            "description": description,
            "license": lic["short_name"].strip(),
            "license_full": lic["full_name"].strip(),
            "license_url": https_url(lic["url"]),
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

    try:
        exercises, licenses, fetched = fetch(args.cache, args.refresh)
    except FetchError as e:
        sys.exit("fetch failed, nothing written: %s" % e)
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
    print("left out by id:", sorted(stats["left_out"]))
    print("left out as (Custom):", len(stats["custom"]), sorted(stats["custom"]))
    print("descriptions left out by id:", sorted(stats["emptied"]))
    print("descriptions with no letters or digits, emptied:",
          sorted(stats["empty_text"]))
    print("descriptions that say where they came from:")
    for i, snippet, emptied in stats["taken_from"]:
        print("  %d%s: %s" % (i, " (left out)" if emptied else "", snippet))
    print("credits: named", stats["named"], "| contributor, an email author:",
          sum(1 for e in entries if e["authors"] == [CONTRIBUTOR])
          - stats["no_author"],
          "| contributor, no author at either level:", stats["no_author"])
    print("author strings replaced by", CONTRIBUTOR + ":",
          stats["email_authors"], "in", stats["email_entries"], "entries")
    print("bytes:", os.path.getsize(path))


if __name__ == "__main__":
    main()
