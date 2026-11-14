# Daybook. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
"""Run with: python -I -m unittest discover -s tools (offline, small fixtures)"""
import json
import os
import re
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_exercise_data import (  # noqa: E402
    build_entries, credit, dump, fetch, plain_text)

LICENSES = [
    {"id": 2, "full_name": "Creative Commons Attribution Share Alike 4",
     "short_name": "CC-BY-SA 4",
     "url": "https://creativecommons.org/licenses/by-sa/4.0/deed.en"},
    {"id": 1, "full_name": " Creative Commons Attribution Share Alike 3",
     "short_name": "CC-BY-SA 3",
     "url": "https://creativecommons.org/licenses/by-sa/3.0/deed.en"},
]


def translation(name="Bench Press", language=2, license=2, author="someone",
                history=None, description="<p>Lie down.</p>", aliases=None):
    return {"name": name, "language": language, "license": license,
            "license_author": author, "author_history": history or [],
            "description": description,
            "aliases": [{"alias": a} for a in (aliases or [])]}


def exercise(id=1, translations=None, **extra):
    ex = {"id": id, "category": {"name": "Chest"},
          "muscles": [{"name": "Pectoralis major", "name_en": "Chest"}],
          "muscles_secondary": [{"name": "Triceps brachii", "name_en": ""}],
          "equipment": [{"name": "Barbell"}],
          "images": [{"image": "https://wger.de/media/x.png"}],
          "translations": translations if translations is not None
          else [translation()]}
    ex.update(extra)
    return ex


def build(*exercises):
    return build_entries(list(exercises), LICENSES)


class HtmlTests(unittest.TestCase):
    def test_paragraphs_become_lines(self):
        self.assertEqual(plain_text("<p>One.</p>\n<p>Two.</p>"), "One.\nTwo.")

    def test_lists_keep_numbers_and_bullets(self):
        text = plain_text("<ol><li>Hinge</li><li>Swing</li></ol><ul><li>Back</li></ul>")
        self.assertEqual(text, "1. Hinge\n2. Swing\n- Back")

    def test_entities_are_decoded(self):
        self.assertEqual(plain_text("<p>Tom &amp; Jerry&nbsp;5 &gt; 3 &#39;x&#39;</p>"),
                         "Tom & Jerry 5 > 3 'x'")

    def test_no_tags_scripts_or_links_remain(self):
        src = ('<p>Keep <b>this</b> <a href="http://x.example">link text</a>'
               '<script>alert(1)</script><style>p{}</style><br/>next</p>'
               "&lt;script&gt;bad&lt;/script&gt;")
        text = plain_text(src)
        self.assertEqual(text, "Keep this link text\nnext\nbad")
        self.assertNotRegex(text, r"<[^>]*>")
        self.assertNotIn("http", text)

    def test_blank_and_missing_descriptions(self):
        self.assertEqual(plain_text(""), "")
        self.assertEqual(plain_text(None), "")
        self.assertEqual(plain_text("<p> </p>"), "")


class AuthorTests(unittest.TestCase):
    def test_plain_author_is_kept_as_written(self):
        self.assertEqual(credit("Miroslav Mazel (imported from Feeel)"),
                         "Miroslav Mazel (imported from Feeel)")

    def test_email_author_is_replaced(self):
        self.assertEqual(credit("someone@example.com"), "wger.de contributor")

    def test_email_inside_a_longer_string_is_replaced(self):
        self.assertEqual(credit("Jane Doe <jane.doe@example.org> and friends"),
                         "wger.de contributor")

    def test_email_with_odd_casing_is_replaced(self):
        self.assertEqual(credit("Some.One@Gmail.COM"), "wger.de contributor")
        self.assertEqual(credit("  TEKKNOKRAT@GMX.DE  "), "wger.de contributor")

    def test_empty_author(self):
        self.assertEqual(credit(""), "")
        self.assertEqual(credit(None), "")


class EntryTests(unittest.TestCase):
    def test_fields_are_kept_and_images_are_not(self):
        entries, _ = build(exercise(
            id=7, translations=[translation(aliases=["Flat Bench", "Chest Press"])]))
        e = entries[0]
        self.assertEqual(e["id"], 7)
        self.assertEqual(e["name"], "Bench Press")
        self.assertEqual(e["aliases"], ["Chest Press", "Flat Bench"][::-1])
        self.assertEqual(e["category"], "Chest")
        self.assertEqual(e["primary_muscles"], ["Chest"])
        self.assertEqual(e["secondary_muscles"], ["Triceps brachii"])
        self.assertEqual(e["equipment"], ["Barbell"])
        self.assertEqual(e["description"], "Lie down.")
        self.assertEqual(e["url"], "https://wger.de/en/exercise/7/view/")
        self.assertNotIn("images", e)
        self.assertNotIn("wger.de/media", json.dumps(e))

    def test_license_of_each_entry_is_kept(self):
        entries, _ = build(
            exercise(1, [translation(license=2)]),
            exercise(2, [translation(name="Squat", license=1)]))
        self.assertEqual(entries[0]["license"], "CC-BY-SA 4")
        self.assertEqual(entries[0]["license_url"],
                         "https://creativecommons.org/licenses/by-sa/4.0/deed.en")
        self.assertEqual(entries[1]["license"], "CC-BY-SA 3")
        self.assertEqual(entries[1]["license_full"],
                         "Creative Commons Attribution Share Alike 3")

    def test_only_the_english_text_is_used(self):
        entries, _ = build(exercise(1, [
            translation(name="Bankdruecken", language=1, author="de"),
            translation(name="Bench Press", language=2, author="en")]))
        self.assertEqual(entries[0]["name"], "Bench Press")
        self.assertEqual(entries[0]["authors"], ["en"])

    def test_entries_without_english_text_are_dropped(self):
        entries, stats = build(exercise(1, [translation(language=1)]),
                               exercise(2, []))
        self.assertEqual(entries, [])
        self.assertEqual(stats["no_english"], 2)

    def test_entries_without_a_name_are_dropped(self):
        entries, stats = build(exercise(1, [translation(name="  ")]),
                               exercise(2, [translation(name="<b></b>")]))
        self.assertEqual(entries, [])
        self.assertEqual(stats["no_name"], 2)

    def test_entries_with_no_known_license_are_dropped(self):
        entries, stats = build(exercise(1, [translation(license=99)]),
                               exercise(2, [translation(license=None)]))
        self.assertEqual(entries, [])
        self.assertEqual(stats["no_license"], 2)

    def test_email_authors_are_replaced_in_entries(self):
        entries, stats = build(exercise(1, [translation(
            author="Joe <JOE@Example.Com>",
            history=["joe@example.com", "Real Name"])]))
        self.assertEqual(entries[0]["authors"], ["wger.de contributor", "Real Name"])
        self.assertEqual(stats["email_entries"], 1)

    def test_author_list_has_history_then_license_author_without_repeats(self):
        entries, _ = build(exercise(1, [translation(
            author="b", history=["a", "b", "a"])]))
        self.assertEqual(entries[0]["authors"], ["a", "b"])

    def test_no_author_at_all_is_credited_to_a_contributor(self):
        entries, stats = build(exercise(1, [translation(author="")]))
        self.assertEqual(entries[0]["authors"], ["wger.de contributor"])
        self.assertEqual(stats["no_author"], 1)

    def test_email_or_tag_in_other_text_fields_is_removed(self):
        entries, _ = build(exercise(1, [translation(
            name="Press <i>x</i>", aliases=["mail me@x.org"])]))
        self.assertEqual(entries[0]["name"], "Press x")
        self.assertEqual(entries[0]["aliases"], ["mail"])


class OutputTests(unittest.TestCase):
    def test_output_is_sorted_stable_and_has_no_timestamps(self):
        a = exercise(5, [translation(name="B")])
        b = exercise(2, [translation(name="A")])
        first = dump(build(a, b)[0])
        second = dump(build(b, a)[0])
        self.assertEqual(first, second)
        data = json.loads(first)
        self.assertEqual([e["id"] for e in data], [2, 5])
        self.assertNotRegex(first, r"\d{4}-\d\d-\d\d")
        self.assertNotIn("\r", first)
        self.assertTrue(first.endswith("]\n"))

    def test_non_ascii_text_is_written_as_utf8(self):
        out = dump(build(exercise(1, [translation(name="Beugestütz")]))[0])
        self.assertIn("Beugestütz", out)

    def test_the_whole_output_has_no_email_or_tag(self):
        out = dump(build(exercise(1, [translation(
            author="a@b.co", description="<p>Mail a@b.co <b>now</b></p>")]))[0])
        self.assertNotRegex(out, r"[^\s@]+@[^\s@]+")
        self.assertNotRegex(out, r"</?[A-Za-z][^>]*>")


class CacheTests(unittest.TestCase):
    def test_build_reads_the_cache_and_needs_no_network(self):
        with tempfile.TemporaryDirectory() as d:
            for name, data in (("exerciseinfo.json", [exercise(3)]),
                               ("licenses.json", LICENSES)):
                with open(os.path.join(d, name), "w", encoding="utf-8") as f:
                    json.dump(data, f)
            with open(os.path.join(d, "fetched.txt"), "w") as f:
                f.write("2026-11-13\n")
            exercises, licenses, fetched = fetch(d)
        self.assertEqual(fetched, "2026-11-13")
        self.assertEqual(build_entries(exercises, licenses)[0][0]["id"], 3)


if __name__ == "__main__":
    unittest.main()
