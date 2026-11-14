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
    API, DESCRIPTION_LEFT_OUT, ENTRY_LEFT_OUT, MAX_PAGES, FetchError,
    build_entries, credit, dump, fetch, https_url, plain_text)

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


class ExerciseLevelAuthorTests(unittest.TestCase):
    def test_exercise_authors_are_used_when_the_text_has_none(self):
        entries, stats = build(exercise(
            1, [translation(author="")], license_author="ruochenma",
            author_history=["ruochenma"]))
        self.assertEqual(entries[0]["authors"], ["ruochenma"])
        self.assertEqual(stats["no_author"], 0)

    def test_the_texts_own_authors_come_first(self):
        entries, _ = build(exercise(
            1, [translation(author="text author")], license_author="other"))
        self.assertEqual(entries[0]["authors"], ["text author"])

    def test_exercise_level_email_still_becomes_a_contributor(self):
        entries, stats = build(exercise(
            1, [translation(author="")], license_author="Me@Example.COM"))
        self.assertEqual(entries[0]["authors"], ["wger.de contributor"])
        self.assertEqual(stats["email_entries"], 1)
        self.assertEqual(stats["no_author"], 0)

    def test_other_languages_authors_are_not_used(self):
        entries, stats = build(exercise(
            1, [translation(author="")],
            total_authors_history=["someone", "a@b.co"]))
        self.assertEqual(entries[0]["authors"], ["wger.de contributor"])
        self.assertEqual(stats["no_author"], 1)

    def test_no_author_only_when_both_levels_are_empty(self):
        entries, stats = build(exercise(
            1, [translation(author="", history=[])], license_author="",
            author_history=[]))
        self.assertEqual(entries[0]["authors"], ["wger.de contributor"])
        self.assertEqual(stats["no_author"], 1)


class LeftOutTests(unittest.TestCase):
    def test_descriptions_from_commercial_sources_are_emptied(self):
        self.assertEqual(
            sorted(DESCRIPTION_LEFT_OUT),
            [202, 204, 260, 445, 580, 599, 655, 688, 1925])
        for reason in DESCRIPTION_LEFT_OUT.values():
            self.assertTrue(reason)
        entries, stats = build(
            exercise(1925, [translation(description="<p>Shrug.</p>")]),
            exercise(202, [translation(name="Other", author="exrx.net")]),
            exercise(3, [translation(name="Kept", description="<p>Fine.</p>")]))
        by_id = {e["id"]: e for e in entries}
        self.assertEqual(by_id[1925]["description"], "")
        self.assertEqual(by_id[1925]["name"], "Bench Press")
        self.assertEqual(by_id[1925]["authors"], ["someone"])
        self.assertEqual(by_id[1925]["license"], "CC-BY-SA 4")
        self.assertEqual(by_id[1925]["primary_muscles"], ["Chest"])
        self.assertEqual(by_id[202]["authors"], ["exrx.net"])
        self.assertEqual(by_id[3]["description"], "Fine.")
        self.assertEqual(stats["emptied"], [1925, 202])

    def test_taken_from_is_reported_but_not_dropped(self):
        entries, stats = build(
            exercise(5, [translation(
                description="<p>Do it. Text taken from SomeSite.com</p>")]),
            exercise(6, [translation(
                description="<p>Copied from Acme Fitness app.</p>")]),
            exercise(7, [translation(description="<p>Plain text.</p>")]))
        self.assertEqual([i for i, _, _ in stats["taken_from"]], [5, 6])
        self.assertIn("SomeSite.com", stats["taken_from"][0][1])
        self.assertEqual(len(entries), 3)
        self.assertIn("taken from", entries[0]["description"])

    def test_names_ending_in_custom_are_left_out(self):
        entries, stats = build(
            exercise(1, [translation(name="Dumbbell Curl (Custom)")]),
            exercise(2, [translation(name="Custom Dumbbell Curl")]))
        self.assertEqual([e["id"] for e in entries], [2])
        self.assertEqual(stats["custom"], [1])

    def test_listed_entries_are_left_out(self):
        self.assertEqual(sorted(ENTRY_LEFT_OUT), [1702, 1949, 2452, 2645])
        for reason in ENTRY_LEFT_OUT.values():
            self.assertTrue(reason)
        entries, stats = build(
            *[exercise(i, [translation(name="X%d" % i)]) for i in ENTRY_LEFT_OUT],
            exercise(10, [translation(name="Kept")]))
        self.assertEqual([e["id"] for e in entries], [10])
        self.assertEqual(sorted(stats["left_out"]), sorted(ENTRY_LEFT_OUT))

    def test_a_description_with_no_letters_or_digits_is_emptied(self):
        entries, stats = build(
            exercise(1, [translation(description="<p>.</p>\n")]),
            exercise(2, [translation(name="B", description="<p>- ...</p>")]),
            exercise(3, [translation(name="C", description="<p>5.</p>")]))
        self.assertEqual([e["description"] for e in entries], ["", "", "5."])
        self.assertEqual(stats["empty_text"], [1, 2])


class LicenseUrlTests(unittest.TestCase):
    def test_creativecommons_urls_use_https_and_names_are_unchanged(self):
        self.assertEqual(
            https_url("http://creativecommons.org/publicdomain/zero/1.0/"),
            "https://creativecommons.org/publicdomain/zero/1.0/")
        self.assertEqual(https_url("https://opendatacommons.org/licenses/odbl/"),
                         "https://opendatacommons.org/licenses/odbl/")
        self.assertEqual(https_url("http://example.org/x"), "http://example.org/x")
        lics = LICENSES + [{
            "id": 3, "full_name": "Creative Commons Public Domain 1.0",
            "short_name": "CC0",
            "url": "http://creativecommons.org/publicdomain/zero/1.0/"}]
        entries, _ = build_entries([exercise(1, [translation(license=3)])], lics)
        self.assertEqual(entries[0]["license"], "CC0")
        self.assertEqual(entries[0]["license_full"],
                         "Creative Commons Public Domain 1.0")
        self.assertEqual(entries[0]["license_url"],
                         "https://creativecommons.org/publicdomain/zero/1.0/")


class ListMarkerTests(unittest.TestCase):
    def test_numbered_item_with_a_paragraph_keeps_its_text(self):
        self.assertEqual(plain_text("<ol><li><p>A</p></li></ol>"), "1. A")

    def test_bullet_item_with_a_paragraph_keeps_its_text(self):
        self.assertEqual(
            plain_text("<ul>\n<li>\n<p>A</p>\n</li>\n<li><p>B</p></li></ul>"),
            "- A\n- B")

    def test_two_paragraphs_in_an_item_stay_on_separate_lines(self):
        self.assertEqual(plain_text("<ol><li><p>A</p><p>B</p></li></ol>"),
                         "1. A\nB")


class ZeroWidthTests(unittest.TestCase):
    def test_zero_width_characters_are_removed_everywhere(self):
        z = "​‌‍﻿"
        entries, _ = build(exercise(1, [translation(
            name=z + "Bench" + z + " Press", aliases=[z + "Flat Bench"],
            description="<p>" + z + "Lie" + z + " down.</p>", author=z + "Sam")]))
        e = entries[0]
        self.assertEqual(e["name"], "Bench Press")
        self.assertEqual(e["aliases"], ["Flat Bench"])
        self.assertEqual(e["description"], "Lie down.")
        self.assertEqual(e["authors"], ["Sam"])
        self.assertNotRegex(dump(entries), "[​-‍﻿]")


class FetchLimitTests(unittest.TestCase):
    def test_a_next_link_off_the_api_stops_the_fetch(self):
        def get(url):
            return {"results": [], "next": "https://evil.example/api/v2/x/"}
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(FetchError) as ctx:
                fetch(os.path.join(d, "c"), get=get, pause=0)
        self.assertIn("not on the wger API", str(ctx.exception))

    def test_a_look_alike_host_is_refused(self):
        def get(url):
            return {"results": [], "next": "https://wger.de.evil.example/api/v2/"}
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(FetchError):
                fetch(os.path.join(d, "c"), get=get, pause=0)

    def test_more_than_the_page_cap_stops_the_fetch(self):
        calls = []

        def get(url):
            calls.append(url)
            return {"results": [],
                    "next": API + "exerciseinfo/?offset=%d" % len(calls)}
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(FetchError):
                fetch(os.path.join(d, "c"), get=get, pause=0)
        self.assertEqual(len(calls), MAX_PAGES)

    def test_nothing_is_written_after_a_failure(self):
        def get(url):
            return {"results": [], "next": "http://elsewhere.example/"}
        with tempfile.TemporaryDirectory() as d:
            cache = os.path.join(d, "c")
            with self.assertRaises(FetchError):
                fetch(cache, get=get, pause=0)
            self.assertEqual(os.listdir(cache), [])

    def test_a_normal_fetch_writes_the_cache(self):
        def get(url):
            if "license" in url:
                return {"results": LICENSES, "next": None}
            return {"results": [exercise(1)], "next": None}
        with tempfile.TemporaryDirectory() as d:
            cache = os.path.join(d, "c")
            exercises, licenses, fetched = fetch(cache, get=get, pause=0)
            self.assertEqual(len(exercises), 1)
            self.assertEqual(sorted(os.listdir(cache)),
                             ["exerciseinfo.json", "fetched.txt",
                              "licenses.json"])


if __name__ == "__main__":
    unittest.main()
