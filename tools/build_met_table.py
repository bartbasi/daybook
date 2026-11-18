# Daybook. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
"""Builds assets/met/compendium_2024.csv from the 2024 Adult Compendium PDF.

Usage: python -I tools/build_met_table.py [--cache DIR] [--out-dir DIR]
                                          [--pdftotext PATH]

Source: the PDF linked from https://pacompendium.com/adult-compendium/. It is
downloaded once into the cache folder (default build/met-cache/, git-ignored),
and the script refuses to go on unless its size and SHA-256 are exactly the
pinned ones. The PDF is untrusted data: it is only ever read with pdftotext.
pdftotext (poppler) is a build tool only, never part of the app. Git for
Windows ships it; on Ubuntu it is poppler-utils.

The text is read with `pdftotext -raw`, not `-layout`. In the layout output the
code column sits a line away from the MET and description columns for about
1 row in 5, so a row's MET lands on the wrong code (02054 comes out empty and
02064 gets its 3.5). Raw order keeps each row together.

Nothing is rounded, renamed, merged or invented. MET values and descriptions
are as published. The only change to the text is that runs of spaces become
one, and a description that wraps onto a second line is joined with a space.
A line the script cannot place is printed and the script stops.

Speeds: for rows under the Running, Walking and Bicycling headings the first
speed written in mph in the description is recorded as min_mph and max_mph.
See parse_speed.
"""
import argparse
import csv
import hashlib
import os
import re
import shutil
import subprocess
import sys
import urllib.request

URL = ("https://pacompendium.com/wp-content/uploads/2025/02/"
       "1_2024-adult-compendium_1_2024.pdf")
PDF_SIZE = 563091
PDF_SHA256 = "ac30234b8f8f813837e282773cfcb3e0fe062334777c2f7b3213429c4fbc251c"
PDF_NAME = "compendium_2024.pdf"
SITE_ROWS = 1114  # the number the Compendium website gives
PDF_ROWS = 1111  # the rows the pinned PDF actually holds (checked 2026-11-17)
USER_AGENT = "met-table-builder/1.0"

COLUMNS = ["code", "heading", "met", "description", "min_mph", "max_mph"]
SPEED_HEADINGS = ("Running", "Walking", "Bicycling")

# One row starts with the major heading, the 5 digit code and the MET value.
# The description follows on the same line, or on the next line or lines.
ROW = re.compile(r"^(?P<heading>[A-Za-z][^0-9]*?) (?P<code>\d{5}) "
                 r"(?P<met>\d+\.\d+)(?: +(?P<desc>\S.*))?$")
# A line that looks like the start of a row but did not parse as one.
LOOSE_ROW = re.compile(r"^[A-Za-z][^0-9]*? \d{5}(?: |$)")
TITLE = "2024 Adult Compendium of Physical Activities"
HEADER = "Major Heading Activity Code MET Value Activity Description"

NUM = r"(\d+(?:\.\d+)?)"
DASH = r"\s*(?:to|-|\u2013)\s*"
RANGE = re.compile(NUM + DASH + NUM + r"\s*mph\b", re.I)
LESS = re.compile(r"(?:less than\s*|<\s*)" + NUM + r"\s*mph\b", re.I)
MORE = re.compile(r"(?:greater than\s*|more than\s*|>\s*|\u2265\s*)" + NUM
                  + r"\s*mph\b", re.I)
SINGLE = re.compile(NUM + r"\s*mph\b", re.I)
# A pace or a metric speed with no mph anywhere is reported, not converted.
OTHER_UNITS = re.compile(r"min/mi|km/h|kph", re.I)


class BuildError(Exception):
    pass


def parse_speed(description):
    """Returns (min_mph, max_mph) as strings, as the description writes them,
    or (None, None) when it gives no speed in mph. Only the first speed in mph
    is read, and only mph: a pace in min/mile or a speed in km/h written
    beside it is ignored, never converted.

    "6-6.3 mph" and "5.0 to 5.2 mph" are a range (min and max).
    "7 mph" is a single speed (min and max equal).
    "less than 2.0 mph" and "<10 mph" give max only.
    "greater than 4 mph", ">20 mph" give min only.
    The number written is kept as written ("7", not "7.0")."""
    found = []  # (position in the text, (min, max))
    for pattern, shape in ((RANGE, "range"), (LESS, "less"), (MORE, "more"),
                           (SINGLE, "single")):
        m = pattern.search(description)
        if m is None:
            continue
        if shape == "range":
            value = (m.group(1), m.group(2))
        elif shape == "less":
            value = (None, m.group(1))
        elif shape == "more":
            value = (m.group(1), None)
        else:
            value = (m.group(1), m.group(1))
        found.append((m.start(), value))
    # The speed written first wins, so "6-6.3 mph" is a range, not 6.3 alone.
    return min(found)[1] if found else (None, None)


def parse_text(text):
    """Turns `pdftotext -raw` output into (rows, problems). A row is a dict
    with the COLUMNS keys (speed columns empty strings). problems is a list of
    lines that could not be placed."""
    rows = []
    problems = []
    current = None
    for raw in text.splitlines():
        line = re.sub(r" {2,}", " ", raw.replace("\f", "")).strip()
        if not line or line == TITLE or line == HEADER:
            continue
        m = ROW.match(line)
        if m:
            current = {"code": m.group("code"), "heading": m.group("heading"),
                       "met": m.group("met"),
                       "description": m.group("desc") or ""}
            rows.append(current)
        elif LOOSE_ROW.match(line):
            problems.append(line)
            current = None
        elif current is not None:
            current["description"] = (current["description"] + " " + line).strip()
        else:
            problems.append(line)
    for r in rows:
        r["min_mph"] = r["max_mph"] = ""
        if r["heading"] in SPEED_HEADINGS:
            lo, hi = parse_speed(r["description"])
            r["min_mph"] = lo or ""
            r["max_mph"] = hi or ""
    return rows, problems


def check_rows(rows):
    """Returns a list of problems: a row with no description, a repeated code,
    codes out of order."""
    out = []
    seen = set()
    last = ""
    for r in rows:
        if not r["description"]:
            out.append("%s has no description" % r["code"])
        if r["code"] in seen:
            out.append("%s appears twice" % r["code"])
        elif r["code"] < last:
            out.append("%s is out of order, after %s" % (r["code"], last))
        seen.add(r["code"])
        last = max(last, r["code"])
    return out


def unit_only_rows(rows):
    """Speed rows that name a pace or km/h but no mph. None today; reported so
    a changed PDF shows them."""
    return [r["code"] for r in rows
            if r["heading"] in SPEED_HEADINGS and r["min_mph"] == ""
            and r["max_mph"] == "" and OTHER_UNITS.search(r["description"])]


def file_digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 16), b""):
            h.update(block)
    return h.hexdigest()


def check_pdf(path, size=PDF_SIZE, sha256=PDF_SHA256):
    """Raises BuildError unless the file has exactly the pinned size and hash."""
    actual = os.path.getsize(path)
    if actual != size:
        raise BuildError("%s is %d bytes, expected %d. Refusing to go on."
                         % (path, actual, size))
    digest = file_digest(path)
    if digest != sha256:
        raise BuildError("%s has SHA-256 %s, expected %s. Refusing to go on."
                         % (path, digest, sha256))


def get_pdf(cache, url=URL, size=PDF_SIZE, sha256=PDF_SHA256):
    """The checked PDF path, downloading it first when it is not in the cache.
    A file already there is checked, never silently replaced."""
    path = os.path.join(cache, PDF_NAME)
    if not os.path.exists(path):
        os.makedirs(cache, exist_ok=True)
        print("downloading from pacompendium.com", file=sys.stderr)
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        part = path + ".part"
        with urllib.request.urlopen(req, timeout=120) as r, \
                open(part, "wb") as f:
            shutil.copyfileobj(r, f)
        os.replace(part, path)
    check_pdf(path, size, sha256)
    return path


def find_pdftotext(explicit=None):
    if explicit:
        return explicit
    found = shutil.which("pdftotext")
    if found:
        return found
    git = shutil.which("git")
    if git:
        root = os.path.dirname(os.path.dirname(git))  # ...\Git
        for sub in (("mingw64", "bin"), ("usr", "bin"), ("bin",)):
            p = os.path.join(root, *sub, "pdftotext.exe")
            if os.path.exists(p):
                return p
    for p in (r"C:\Program Files\Git\mingw64\bin\pdftotext.exe",
              r"C:\Program Files\Git\usr\bin\pdftotext.exe"):
        if os.path.exists(p):
            return p
    raise BuildError("pdftotext not found. Install poppler-utils, or use "
                     "Git for Windows, or pass --pdftotext PATH.")


def pdf_to_text(pdf, pdftotext):
    result = subprocess.run([pdftotext, "-raw", "-enc", "UTF-8", pdf, "-"],
                            capture_output=True, check=True, timeout=120)
    return result.stdout.decode("utf-8")


def write_csv(rows, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(COLUMNS)
        for r in sorted(rows, key=lambda r: r["code"]):
            w.writerow([r[c] for c in COLUMNS])


def main(argv=None):
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default=os.path.join(root, "build", "met-cache"))
    ap.add_argument("--out-dir", default=os.path.join(root, "assets", "met"))
    ap.add_argument("--pdftotext")
    args = ap.parse_args(argv)
    try:
        pdf = get_pdf(args.cache)
        text = pdf_to_text(pdf, find_pdftotext(args.pdftotext))
    except (BuildError, OSError, subprocess.SubprocessError) as e:
        print("error: %s" % e, file=sys.stderr)
        return 1
    rows, problems = parse_text(text)
    problems += check_rows(rows)
    if problems:
        print("Could not place these lines, nothing written:", file=sys.stderr)
        for p in problems:
            print("  " + p, file=sys.stderr)
        return 1
    print("rows: %d (the Compendium website says %d, so %d are not in this PDF; "
          "the PDF does not say which)" % (len(rows), SITE_ROWS,
                                           SITE_ROWS - len(rows)))
    if len(rows) != PDF_ROWS:
        print("error: this PDF held %d rows when it was checked, now %d. "
              "Nothing written." % (PDF_ROWS, len(rows)), file=sys.stderr)
        return 1
    for h in SPEED_HEADINGS:
        banded = [r for r in rows if r["heading"] == h and
                  (r["min_mph"] or r["max_mph"])]
        print("%s: %d rows with a speed" % (h, len(banded)))
    only = unit_only_rows(rows)
    if only:
        print("pace or km/h but no mph, no speed recorded: " + ", ".join(only))
    write_csv(rows, os.path.join(args.out_dir, "compendium_2024.csv"))
    print("written to " + os.path.join(args.out_dir, "compendium_2024.csv"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
