# Daybook. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
"""Builds assets/food/usda.sqlite.gz, the bundled read-only USDA reference data.

Usage: python -I tools/build_food_db.py [--cache DIR] [--out-dir DIR] [--no-fndds]

Sources (USDA FoodData Central, public domain, CC0 1.0), downloaded into the
cache folder (default build/usda-cache/) and checked against pinned SHA-256
values. Only the Python standard library is used.

Canonical nutrient fallbacks, applied at build time, original id preferred:
  energy 1008 <- 2048 (Atwater specific) <- 2047 (Atwater general) <- 1062 kJ / 4.184
  fat 1004 <- 1085, carbs 1005 <- 1050, sugar 2000 <- 1063
  folate DFE 1190 <- 1177, only when folic acid 1186 is listed as 0 (DFE is food
  folate + 1.7 x folic acid, so for enriched foods total folate understates it;
  without a folic acid value 1190 stays absent)
Foods that still have no energy value are skipped.
"""
import argparse
import csv
import datetime
import gzip
import hashlib
import io
import json
import os
import shutil
import sqlite3
import struct
import sys
import urllib.request
import zipfile

BASE_URL = "https://fdc.nal.usda.gov/fdc-datasets/"
SOURCES = {
    "sr_legacy": (
        "FoodData_Central_sr_legacy_food_csv_2018-04.zip",
        "b80817294b8850530aaedf2e515c02593b1824f763a0ff356e5c2081643e6fd0",
    ),
    "foundation": (
        "FoodData_Central_foundation_food_json_2026-10-29.zip",
        "dd414cc9f1a132626bad354ef6655972c78b44aff14f16114dc899708663c579",
    ),
    "fndds": (
        "FoodData_Central_survey_food_json_2024-10-31.zip",
        "dfb06ae7ddc397ccd570b91c14b75438ab2ba39f64f22d321f61d4a52a77f3eb",
    ),
}
DATA_VERSION = "2026-10-29"  # the newest release used (Foundation Foods)
KCAL_PER_KJ = 1 / 4.184

# (target id, fallback source ids in order)
FALLBACKS = [
    (1008, [2048, 2047]),
    (1004, [1085]),
    (1005, [1050]),
    (2000, [1063]),
]

SCHEMA = """
CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE nutrient(id INTEGER PRIMARY KEY, name TEXT, unit TEXT, rank REAL);
CREATE TABLE food(id INTEGER PRIMARY KEY, dataset TEXT, description TEXT, category TEXT);
CREATE TABLE food_nutrient(
  food_id INTEGER, nutrient_id INTEGER, amount REAL,
  PRIMARY KEY(food_id, nutrient_id)) WITHOUT ROWID;
CREATE TABLE food_portion(
  food_id INTEGER, seq INTEGER, label TEXT, gram_weight REAL,
  PRIMARY KEY(food_id, seq)) WITHOUT ROWID;
CREATE INDEX food_description ON food(description COLLATE NOCASE);
"""


def fetch(name, sha, cache):
    path = os.path.join(cache, name)
    if not os.path.exists(path):
        os.makedirs(cache, exist_ok=True)
        print("downloading", name, file=sys.stderr)
        urllib.request.urlretrieve(BASE_URL + name, path)
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    if h.hexdigest() != sha:
        sys.exit("SHA-256 mismatch for %s: got %s" % (name, h.hexdigest()))
    return path


def unit_name(u):
    u = (u or "").strip()
    if u.upper() == "UG":
        return "µg"
    return u.lower() if u.isupper() else u


def fmt_amount(a):
    a = float(a)
    return str(int(a)) if a == int(a) else ("%.2f" % a).rstrip("0").rstrip(".")


def make_label(amount, unit, modifier):
    label = fmt_amount(amount) + (" " + unit if unit else "")
    modifier = (modifier or "").strip()
    if modifier:
        label += (", " if unit else " ") + modifier
    return label


class Collector:
    """Gathers foods from all sources in memory, then writes them out."""

    def __init__(self):
        self.nutrients = {}  # id -> (name, unit, rank)
        self.foods = {}  # id -> (dataset, description, category)
        self.amounts = {}  # id -> {nutrient id: amount}
        self.portions = {}  # id -> [(source seq, label, grams)]

    def nutrient(self, nid, name, unit, rank):
        self.nutrients.setdefault(nid, (name, unit_name(unit), rank))

    def food(self, fid, dataset, description, category):
        self.foods[fid] = (dataset, description.strip(), (category or "").strip())
        self.amounts[fid] = {}
        self.portions[fid] = []

    def portion(self, fid, seq, label, grams):
        if grams is not None and grams > 0:
            self.portions[fid].append((seq or 0, label, grams))


def read_sr_legacy(path, c):
    z = zipfile.ZipFile(path)
    root = z.namelist()[0]

    def rows(name):
        with z.open(root + name) as f:
            yield from csv.DictReader(io.TextIOWrapper(f, encoding="utf-8"))

    for r in rows("nutrient.csv"):
        c.nutrient(int(r["id"]), r["name"], r["unit_name"], float(r["rank"] or 0))
    cats = {r["id"]: r["description"] for r in rows("food_category.csv")}
    units = {r["id"]: r["name"] for r in rows("measure_unit.csv")}
    for r in rows("food.csv"):
        if r["data_type"] == "sr_legacy_food":
            c.food(int(r["fdc_id"]), "sr_legacy", r["description"],
                   cats.get(r["food_category_id"]))
    for r in rows("food_nutrient.csv"):
        fid = int(r["fdc_id"])
        if fid in c.amounts and r["amount"] != "":
            c.amounts[fid][int(r["nutrient_id"])] = float(r["amount"])
    for r in rows("food_portion.csv"):
        fid = int(r["fdc_id"])
        if fid not in c.portions:
            continue
        unit = "" if r["measure_unit_id"] == "9999" else units.get(r["measure_unit_id"], "")
        unit = unit or r["portion_description"]
        c.portion(fid, int(r["seq_num"] or 0),
                  make_label(r["amount"] or 1, unit, r["modifier"]),
                  float(r["gram_weight"] or 0))


def read_json_nutrients(c, item, fid):
    for n in item.get("foodNutrients", []):
        nut = n.get("nutrient") or {}
        if "id" not in nut or n.get("amount") is None:
            continue
        c.nutrient(nut["id"], nut.get("name", ""), nut.get("unitName", ""),
                   nut.get("rank", 0))
        c.amounts[fid][nut["id"]] = float(n["amount"])


def read_foundation(path, c):
    z = zipfile.ZipFile(path)
    data = json.load(z.open(z.namelist()[0]))["FoundationFoods"]
    for item in data:
        fid = item["fdcId"]
        c.food(fid, "foundation", item["description"],
               (item.get("foodCategory") or {}).get("description"))
        read_json_nutrients(c, item, fid)
        for p in item.get("foodPortions", []):
            mu = (p.get("measureUnit") or {}).get("name", "")
            if mu == "RACC":  # label would be meaningless
                continue
            if mu == "undetermined":
                mu = ""
            mu = mu or p.get("portionDescription") or ""
            c.portion(fid, p.get("sequenceNumber"),
                      make_label(p.get("amount") or 1, mu, p.get("modifier")),
                      p.get("gramWeight"))


def read_fndds(path, c):
    z = zipfile.ZipFile(path)
    data = json.load(z.open(z.namelist()[0]))["SurveyFoods"]
    for item in data:
        fid = item["fdcId"]
        c.food(fid, "fndds", item["description"],
               (item.get("wweiaFoodCategory") or {}).get("wweiaFoodCategoryDescription"))
        read_json_nutrients(c, item, fid)
        for p in item.get("foodPortions", []):
            label = (p.get("portionDescription") or "").strip()
            # "Guideline amount per ..." rows are survey coding aids, not portions.
            if (label and label != "Quantity not specified"
                    and not label.startswith("Guideline amount")):
                c.portion(fid, p.get("sequenceNumber"), label, p.get("gramWeight"))


def apply_fallbacks(amounts):
    if 1190 not in amounts and 1177 in amounts and amounts.get(1186) == 0:
        amounts[1190] = amounts[1177]
    for target, sources in FALLBACKS:
        if target in amounts:
            continue
        for s in sources:
            if s in amounts:
                amounts[target] = amounts[s]
                break
        else:
            if target == 1008 and 1062 in amounts:
                amounts[target] = amounts[1062] * KCAL_PER_KJ


def write_db(c, path, releases, build_date):
    if os.path.exists(path):
        os.remove(path)
    db = sqlite3.connect(path)
    db.executescript(SCHEMA)
    skipped = {}
    used_nutrients = set()
    for fid, (dataset, desc, cat) in c.foods.items():
        amounts = c.amounts[fid]
        apply_fallbacks(amounts)
        if 1008 not in amounts:
            skipped[dataset] = skipped.get(dataset, 0) + 1
            continue
        db.execute("INSERT INTO food VALUES(?,?,?,?)", (fid, dataset, desc, cat))
        db.executemany("INSERT INTO food_nutrient VALUES(?,?,?)",
                       [(fid, n, a) for n, a in amounts.items()])
        used_nutrients.update(amounts)
        ports = sorted(c.portions[fid], key=lambda p: p[0])
        db.executemany("INSERT INTO food_portion VALUES(?,?,?,?)",
                       [(fid, i + 1, p[1], p[2]) for i, p in enumerate(ports)])
    for nid in sorted(used_nutrients):
        name, unit, rank = c.nutrients.get(nid, ("", "", 0))
        db.execute("INSERT INTO nutrient VALUES(?,?,?,?)", (nid, name, unit, rank))
    meta = {
        "data_version": DATA_VERSION,
        "schema_version": "1",
        "build_date": build_date,
        "releases": ", ".join(releases),
        "energy_fallback": "1008 <- 2048 <- 2047 <- 1062 kJ / 4.184; "
                           "foods with no energy are skipped",
        "other_fallbacks": "1004 <- 1085; 1005 <- 1050; 2000 <- 1063; "
                           "1190 <- 1177 only when 1186 is 0",
    }
    db.executemany("INSERT INTO meta VALUES(?,?)", meta.items())
    db.commit()
    counts = dict(db.execute("SELECT dataset, COUNT(*) FROM food GROUP BY dataset"))
    db.execute("VACUUM")
    db.close()
    return counts, skipped


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default="build/usda-cache")
    ap.add_argument("--out-dir", default="assets/food")
    ap.add_argument("--no-fndds", action="store_true")
    args = ap.parse_args()

    readers = [("sr_legacy", read_sr_legacy), ("foundation", read_foundation)]
    if not args.no_fndds:
        readers.append(("fndds", read_fndds))
    c = Collector()
    releases = []
    for key, reader in readers:
        name, sha = SOURCES[key]
        reader(fetch(name, sha, args.cache), c)
        releases.append(name[len("FoodData_Central_"):-len(".zip")])

    os.makedirs(args.out_dir, exist_ok=True)
    db_path = os.path.join(args.out_dir, "usda.sqlite")
    build_date = datetime.date.today().isoformat()
    counts, skipped = write_db(c, db_path, releases, build_date)

    gz_path = db_path + ".gz"
    with open(db_path, "rb") as src, open(gz_path, "wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw,
                           compresslevel=9, mtime=0) as dst:
            shutil.copyfileobj(src, dst)
    # The version changes whenever the content does, so rebuilt data reaches
    # installed copies. It is the release plus the CRC-32 and size of the
    # uncompressed file, as the gzip trailer holds them (a test checks this).
    with open(gz_path, "rb") as f:
        f.seek(-8, os.SEEK_END)
        crc, size = struct.unpack("<II", f.read(8))
    version = "%s-%08x%x" % (DATA_VERSION, crc, size)
    with open(os.path.join(args.out_dir, "usda_version.txt"), "w") as f:
        f.write(version + "\n")
    print("version:", version)

    print("foods:", counts)
    print("skipped for no energy:", skipped)
    print("sqlite bytes:", os.path.getsize(db_path))
    print("gzip bytes:", os.path.getsize(gz_path))
    os.remove(db_path)


if __name__ == "__main__":
    main()
