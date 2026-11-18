# Daybook. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
"""Run with: python -I -m unittest discover -s tools (offline, no pdftotext).

The parsing rules are tested on lines copied from the real PDF text, and the
committed CSV is checked against the rules and the spot values."""
import csv
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_met_table import (  # noqa: E402
    COLUMNS, CSV_SHA256, PDF_ROWS, BuildError, check_pdf, check_rows,
    csv_bytes, file_digest, parse_speed, parse_text, unit_only_rows,
    write_csv)

CSV_PATH = os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), "assets", "met", "compendium_2024.csv")

# Real lines from `pdftotext -raw`, including a row that wraps and rows whose
# description sits on the lines after the MET.
SAMPLE = """Major Heading Activity Code MET Value Activity Description
Bicycling 01003 14.0 Bicycling, mountain, uphill, vigorous
Conditioning Exercise 02050 6.0
Resistance (weight lifting - free weight, nautilus or universal-type), power lifting or body building, vigorous effort (Taylor Code
210)
Conditioning Exercise 02054 3.5 Resistance (weight) training, multiple exercises, 8-15 reps at varied resistance
Dancing 03039 13.0
ballroom dance, DanceSport competition (modern waltz, tango, Viennese waltz, slow fox, quick step, samba, chacha, rumba,
paso doble, jive)
2024 Adult Compendium of Physical Activities
Lawn & Garden 08202 7.5 Shoveling snow, by hand, vigorous effort
Running 12050 9.3 Running, 6-6.3 mph (10 min/mile)
Running 12060 10.5 Running, 6.7 mph (9 min/mile)
Walking 17190 3.8 Walking, 2.8 to 3.4 mph, level, moderate pace, firm surface
"""


def by_code(rows):
    return {r["code"]: r for r in rows}


def real_rows():
    with open(CSV_PATH, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


class ParseTextTests(unittest.TestCase):
    def setUp(self):
        self.rows, self.problems = parse_text(SAMPLE)
        self.by = by_code(self.rows)

    def test_every_row_is_found_and_nothing_is_left_over(self):
        self.assertEqual(self.problems, [])
        self.assertEqual([r["code"] for r in self.rows],
                         ["01003", "02050", "02054", "03039", "08202",
                          "12050", "12060", "17190"])

    def test_heading_code_met_and_description(self):
        r = self.by["01003"]
        self.assertEqual((r["heading"], r["met"], r["description"]),
                         ("Bicycling", "14.0",
                          "Bicycling, mountain, uphill, vigorous"))
        self.assertEqual(self.by["08202"]["heading"], "Lawn & Garden")
        self.assertEqual(self.by["02054"]["heading"], "Conditioning Exercise")

    def test_description_on_the_next_line_is_joined(self):
        self.assertEqual(
            self.by["02050"]["description"],
            "Resistance (weight lifting - free weight, nautilus or "
            "universal-type), power lifting or body building, vigorous effort "
            "(Taylor Code 210)")

    def test_description_over_three_lines_is_joined(self):
        d = self.by["03039"]["description"]
        self.assertTrue(d.startswith("ballroom dance, DanceSport"))
        self.assertTrue(d.endswith("paso doble, jive)"))
        self.assertIn("rumba, paso doble", d)

    def test_met_is_kept_as_written(self):
        self.assertEqual(self.by["01003"]["met"], "14.0")
        self.assertEqual(self.by["12050"]["met"], "9.3")

    def test_page_title_is_not_a_continuation(self):
        self.assertNotIn("2024 Adult", self.by["03039"]["description"])

    def test_spot_values(self):
        self.assertEqual(self.by["12050"]["met"], "9.3")
        self.assertEqual(self.by["02054"]["met"], "3.5")
        self.assertEqual(self.by["12060"]["met"], "10.5")
        self.assertEqual(self.by["17190"]["met"], "3.8")

    def test_speed_columns_only_for_running_walking_bicycling(self):
        self.assertEqual((self.by["12050"]["min_mph"],
                          self.by["12050"]["max_mph"]), ("6", "6.3"))
        self.assertEqual((self.by["01003"]["min_mph"],
                          self.by["01003"]["max_mph"]), ("", ""))
        # Not under a speed heading: nothing is read even if mph were written.
        rows, _ = parse_text("Sports 15000 5.0 Cycling, 10 mph\n")
        self.assertEqual((rows[0]["min_mph"], rows[0]["max_mph"]), ("", ""))

    def test_a_line_that_cannot_be_placed_is_reported(self):
        rows, problems = parse_text("Running 12050 nine point three\n")
        self.assertEqual(rows, [])
        self.assertEqual(problems, ["Running 12050 nine point three"])
        rows, problems = parse_text("stray words with no row before them\n")
        self.assertEqual(problems, ["stray words with no row before them"])

    def test_double_spaces_become_one(self):
        rows, _ = parse_text("Walking  17110  6.5  Race   walking\n")
        self.assertEqual(rows[0]["description"], "Race walking")

    def test_check_rows_names_the_trouble(self):
        rows, _ = parse_text("Running 12050 9.3\nRunning 12060 10.5 x\n"
                             "Running 12060 10.5 x\nRunning 12020 7.5 y\n")
        self.assertEqual(check_rows(rows), [
            "12050 has no description", "12060 appears twice",
            "12020 is out of order, after 12060"])


class SpeedTests(unittest.TestCase):
    """The speed forms, each read from a real description."""

    def test_range_with_a_dash(self):
        self.assertEqual(parse_speed("Running, 6-6.3 mph (10 min/mile)"),
                         ("6", "6.3"))
        self.assertEqual(parse_speed("Bicycling, 10-11.9 mph, leisure, slow"),
                         ("10", "11.9"))

    def test_range_with_a_dash_and_spaces(self):
        self.assertEqual(parse_speed("Running, 5.5 -5.8 mph"), ("5.5", "5.8"))
        self.assertEqual(
            parse_speed("Running, 5.0 - 5.9 mph, 1.0 to 3.0 kg backpack"),
            ("5.0", "5.9"))

    def test_range_with_to(self):
        self.assertEqual(
            parse_speed("Walking, 2.8 to 3.4 mph, level, moderate pace"),
            ("2.8", "3.4"))

    def test_single_speed_is_min_and_max(self):
        self.assertEqual(parse_speed("Running, 6.7 mph (9 min/mile)"),
                         ("6.7", "6.7"))
        self.assertEqual(parse_speed("Running, 7 mph (8.5 min/mile)"),
                         ("7", "7"))
        self.assertEqual(parse_speed("Bicycling, leisure 5.5 mph"),
                         ("5.5", "5.5"))

    def test_less_than_has_a_max_only(self):
        self.assertEqual(parse_speed("Walking, less than 2.0 mph, level"),
                         (None, "2.0"))
        self.assertEqual(parse_speed("Bicycling, <10 mph, leisure"),
                         (None, "10"))

    def test_greater_than_has_a_min_only(self):
        self.assertEqual(parse_speed("Bicycling, >20 mph, racing"),
                         ("20", None))
        self.assertEqual(parse_speed("Running uphill, >1.6mph, 10-30% incline"),
                         ("1.6", None))

    def test_no_space_before_mph(self):
        self.assertEqual(parse_speed("Running uphill, 4.5mph, 5% incline"),
                         ("4.5", "4.5"))

    def test_a_pace_or_km_beside_the_mph_is_ignored(self):
        self.assertEqual(
            parse_speed("Walking, 4.0 to 4.4 mph (6.4 to 7.0 km/h), level"),
            ("4.0", "4.4"))
        self.assertEqual(parse_speed("Running, 10 mph (6 min/mile)"),
                         ("10", "10"))

    def test_the_first_speed_written_wins(self):
        self.assertEqual(
            parse_speed("Bicycling, 16-19 mph, racing/not drafting or "
                        ">19 mph drafting, very fast"), ("16", "19"))

    def test_no_speed_means_no_band(self):
        for text in ("Running, self-selected pace", "Jogging, in place",
                     "Walking the dog", "Bicycling, mountain, uphill, vigorous",
                     "Walking, 5 to 20 degrees C, 40 lb (18.2 kg) load",
                     "Running, stairs, up", "Walking, backward, level"):
            self.assertEqual(parse_speed(text), (None, None), text)

    def test_a_pace_or_km_with_no_mph_is_not_converted_but_reported(self):
        self.assertEqual(parse_speed("Running, 10 km/h"), (None, None))
        self.assertEqual(parse_speed("Running, 6 min/mile"), (None, None))
        rows, _ = parse_text("Running 12999 9.0 Running, 10 km/h\n"
                             "Running 12998 9.0 Running, 6 mph\n")
        self.assertEqual(unit_only_rows(rows), ["12999"])


class PdfCheckTests(unittest.TestCase):
    def write(self, data):
        d = tempfile.mkdtemp()
        path = os.path.join(d, "x.pdf")
        with open(path, "wb") as f:
            f.write(data)
        return path

    def test_the_pinned_file_passes(self):
        import hashlib
        data = b"pretend pdf"
        path = self.write(data)
        check_pdf(path, len(data), hashlib.sha256(data).hexdigest())

    def test_a_different_hash_is_refused(self):
        import hashlib
        path = self.write(b"pretend pdf")
        with self.assertRaises(BuildError) as cm:
            check_pdf(path, 11, hashlib.sha256(b"another one").hexdigest())
        self.assertIn("SHA-256", str(cm.exception))

    def test_a_different_size_is_refused_before_hashing(self):
        path = self.write(b"pretend pdf")
        with self.assertRaises(BuildError) as cm:
            check_pdf(path, 12, "0" * 64)
        self.assertIn("bytes", str(cm.exception))

    def test_the_real_pins_refuse_a_wrong_file(self):
        with self.assertRaises(BuildError):
            check_pdf(self.write(b"not the compendium"))


class CommittedCsvTests(unittest.TestCase):
    """The committed asset, checked without the PDF."""

    @classmethod
    def setUpClass(cls):
        cls.rows = real_rows()
        cls.by = by_code(cls.rows)

    def test_columns_and_row_count(self):
        with open(CSV_PATH, encoding="utf-8") as f:
            self.assertEqual(f.readline().rstrip("\n").split(","), COLUMNS)
        self.assertEqual(len(self.rows), PDF_ROWS)

    def test_codes_are_unique_five_digits_in_order(self):
        codes = [r["code"] for r in self.rows]
        self.assertEqual(len(set(codes)), len(codes))
        self.assertEqual(codes, sorted(codes))
        for c in codes:
            self.assertRegex(c, r"^\d{5}$")

    def test_every_row_has_a_description_and_a_met(self):
        for r in self.rows:
            self.assertTrue(r["description"], r["code"])
            # One decimal, except 18290 which the PDF prints as "8.00".
            self.assertRegex(r["met"], r"^\d+\.\d+$", r["code"])
            self.assertEqual(r["description"], r["description"].strip())
            self.assertNotIn("  ", r["description"], r["code"])

    def test_22_headings(self):
        self.assertEqual(len({r["heading"] for r in self.rows}), 22)

    def test_spot_values(self):
        self.assertEqual(self.by["12050"]["met"], "9.3")
        self.assertEqual(self.by["02054"]["met"], "3.5")
        self.assertEqual(self.by["12060"]["met"], "10.5")
        self.assertEqual(self.by["17190"]["met"], "3.8")

    def test_wrapped_rows_are_joined(self):
        # 02050, 03039 and 05050 really wrap in the PDF text. Each keeps its
        # own MET and has its second line joined with one space.
        for code, met, tail in (
                ("02050", "6.0", "vigorous effort (Taylor Code 210)"),
                ("03039", "13.0", "rumba, paso doble, jive)"),
                ("05050", "2.0", "manual appliances, light effort")):
            self.assertEqual(self.by[code]["met"], met, code)
            self.assertTrue(self.by[code]["description"].endswith(tail), code)
            self.assertNotIn("  ", self.by[code]["description"], code)
        self.assertEqual(self.by["02054"]["met"], "3.5")
        self.assertEqual(self.by["02057"]["met"], "6.5")

    def test_general_entries(self):
        for code, met, text in (
                ("12145", "10.5", "Running, self-selected pace"),
                ("17190", "3.8", "Walking, 2.8 to 3.4 mph, level, moderate "
                                 "pace, firm surface"),
                ("01014", "7.0", "Bicycling, general")):
            self.assertEqual((self.by[code]["met"],
                              self.by[code]["description"]), (met, text))

    def test_speed_columns_match_the_rules_on_every_real_row(self):
        for r in self.rows:
            if r["heading"] in ("Running", "Walking", "Bicycling"):
                lo, hi = parse_speed(r["description"])
                self.assertEqual((r["min_mph"], r["max_mph"]),
                                 (lo or "", hi or ""), r["code"])
            else:
                self.assertEqual((r["min_mph"], r["max_mph"]), ("", ""),
                                 r["code"])

    def test_speed_forms_on_real_rows(self):
        def speed(code):
            return (self.by[code]["min_mph"], self.by[code]["max_mph"])
        self.assertEqual(speed("12050"), ("6", "6.3"))        # dash range
        self.assertEqual(speed("12045"), ("5.5", "5.8"))      # " -" range
        self.assertEqual(speed("12030"), ("5.0", "5.2"))      # "to" range
        self.assertEqual(speed("12060"), ("6.7", "6.7"))      # single
        self.assertEqual(speed("12070"), ("7", "7"))          # single, whole
        self.assertEqual(speed("17151"), ("", "2.0"))         # less than
        self.assertEqual(speed("01010"), ("", "10"))          # <
        self.assertEqual(speed("01060"), ("20", ""))          # >
        self.assertEqual(speed("17220"), ("4.0", "4.4"))      # km/h beside
        self.assertEqual(speed("12120"), ("10", "10"))        # pace beside
        self.assertEqual(speed("01050"), ("16", "19"))        # first of two
        self.assertEqual(speed("12145"), ("", ""))            # no speed
        self.assertEqual(speed("17165"), ("", ""))            # no speed

    def test_no_speed_row_gives_only_a_pace_or_km(self):
        self.assertEqual(unit_only_rows(self.rows), [])

    def test_the_pinned_hash_is_the_hash_of_the_committed_file(self):
        self.assertEqual(file_digest(CSV_PATH), CSV_SHA256)

    def test_write_csv_round_trips(self):
        rows, _ = parse_text(SAMPLE)
        d = tempfile.mkdtemp()
        path = os.path.join(d, "out", "x.csv")
        write_csv(rows, path)
        with open(path, encoding="utf-8", newline="") as f:
            back = list(csv.DictReader(f))
        self.assertEqual([r["code"] for r in back],
                         sorted(r["code"] for r in rows))
        self.assertEqual(by_code(back)["12050"]["max_mph"], "6.3")


class CsvPinTests(unittest.TestCase):
    def test_a_stray_line_after_a_row_stops_the_build(self):
        # A page number from another pdftotext build would be joined to the
        # row above without any error. The pinned hash catches it.
        clean, _ = parse_text(SAMPLE)
        pin = __import__("hashlib").sha256(csv_bytes(clean)).hexdigest()
        stray = SAMPLE.replace(
            "Running 12060 10.5 Running, 6.7 mph (9 min/mile)\n",
            "Running 12060 10.5 Running, 6.7 mph (9 min/mile)\n- 41 -\n")
        rows, problems = parse_text(stray)
        self.assertEqual(problems, [])  # the parser itself does not notice
        d = tempfile.mkdtemp()
        path = os.path.join(d, "x.csv")
        with self.assertRaises(BuildError) as cm:
            write_csv(rows, path, pin)
        self.assertIn("committed", str(cm.exception))
        self.assertFalse(os.path.exists(path))

    def test_the_same_text_is_written_when_the_hash_matches(self):
        rows, _ = parse_text(SAMPLE)
        pin = __import__("hashlib").sha256(csv_bytes(rows)).hexdigest()
        d = tempfile.mkdtemp()
        path = os.path.join(d, "x.csv")
        write_csv(rows, path, pin)
        self.assertEqual(file_digest(path), pin)

    def test_a_mismatch_leaves_the_existing_file_alone(self):
        rows, _ = parse_text(SAMPLE)
        d = tempfile.mkdtemp()
        path = os.path.join(d, "x.csv")
        with open(path, "wb") as f:
            f.write(b"old")
        with self.assertRaises(BuildError):
            write_csv(rows, path, "0" * 64)
        with open(path, "rb") as f:
            self.assertEqual(f.read(), b"old")

    def test_a_mismatch_writes_the_build_to_the_scratch_folder(self):
        rows, _ = parse_text(SAMPLE)
        d = tempfile.mkdtemp()
        path = os.path.join(d, "x.csv")
        scratch = os.path.join(d, "cache")
        with self.assertRaises(BuildError) as cm:
            write_csv(rows, path, "0" * 64, scratch_dir=scratch)
        built = os.path.join(scratch, "compendium_2024.built.csv")
        self.assertIn(built, str(cm.exception))
        self.assertIn("update CSV_SHA256", str(cm.exception))
        self.assertFalse(os.path.exists(path))
        with open(built, "rb") as f:
            self.assertEqual(f.read(), csv_bytes(rows))


if __name__ == "__main__":
    unittest.main()
