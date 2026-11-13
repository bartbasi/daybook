# Daybook. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
"""Run with: python -I -m unittest discover -s tools"""
import json
import os
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_food_db import Collector, apply_fallbacks, read_fndds  # noqa: E402


class FallbackTests(unittest.TestCase):
    def test_folate_filled_only_when_folic_acid_is_zero(self):
        a = {1177: 47.0, 1186: 0.0}
        apply_fallbacks(a)
        self.assertEqual(a[1190], 47.0)

    def test_folate_not_filled_for_enriched_food(self):
        a = {1177: 160.0, 1186: 100.0}
        apply_fallbacks(a)
        self.assertNotIn(1190, a)

    def test_folate_not_filled_without_folic_acid_value(self):
        a = {1177: 160.0}
        apply_fallbacks(a)
        self.assertNotIn(1190, a)

    def test_listed_dfe_is_kept(self):
        a = {1177: 154.0, 1186: 0.0, 1190: 291.0}
        apply_fallbacks(a)
        self.assertEqual(a[1190], 291.0)

    def test_energy_fallback_order(self):
        a = {2047: 61.8, 2048: 55.6, 1062: 100.0}
        apply_fallbacks(a)
        self.assertEqual(a[1008], 55.6)
        b = {1062: 418.4}
        apply_fallbacks(b)
        self.assertAlmostEqual(b[1008], 100.0)


class FnddsPortionTests(unittest.TestCase):
    def test_quantity_not_specified_is_kept_and_guideline_amount_is_not(self):
        item = {
            "fdcId": 1,
            "description": "Egg, whole, cooked",
            "foodNutrients": [],
            "foodPortions": [
                {"sequenceNumber": 1, "portionDescription": "1 egg", "gramWeight": 46},
                {"sequenceNumber": 2, "portionDescription": "Guideline amount per cup",
                 "gramWeight": 243},
                {"sequenceNumber": 3, "portionDescription": "Quantity not specified",
                 "gramWeight": 50},
            ],
        }
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "fndds.zip")
            with zipfile.ZipFile(path, "w") as z:
                z.writestr("survey.json", json.dumps({"SurveyFoods": [item]}))
            c = Collector()
            read_fndds(path, c)
        self.assertEqual(
            c.portions[1], [(1, "1 egg", 46), (3, "Quantity not specified", 50)]
        )


if __name__ == "__main__":
    unittest.main()
