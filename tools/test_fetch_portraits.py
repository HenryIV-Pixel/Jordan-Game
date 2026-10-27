"""Offline tests for fetch_portraits.py (no network). Run: python tools/test_fetch_portraits.py"""
import csv
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fetch_portraits as fp  # noqa: E402


def human(qid, image=None, country=None, desc="", born="+1935-11-14T00:00:00Z"):
    claims = {"P31": [{"mainsnak": {"datavalue": {"value": {"id": "Q5"}}}}],
              "P569": [{"mainsnak": {"datavalue": {"value": {"time": born}}}}]}
    if image:
        claims["P18"] = [{"mainsnak": {"datavalue": {"value": image}}}]
    if country:
        claims["P27"] = [{"mainsnak": {"datavalue": {"value": {"id": country}}}}]
    return {"id": qid, "claims": claims, "descriptions": {"en": {"value": desc}}}


class FakeResp:
    def __init__(self, data=None, content=b"", status=200):
        self._d, self.content, self.status_code = data, content, status

    def json(self):
        return self._d

    def raise_for_status(self):
        if self.status_code >= 400:
            raise RuntimeError(self.status_code)


class FakeSession:
    """Answers like Wikidata/Commons for three people: one good match, one with a non-free image, one unknown."""

    def __init__(self):
        self.headers = {}
        buf = io.BytesIO()
        Image.new("RGB", (900, 1200), (120, 100, 90)).save(buf, "JPEG")
        self.jpeg = buf.getvalue()
        self.calls = 0

    def get(self, url, params=None, timeout=None):
        self.calls += 1
        p = params or {}
        if url == fp.WIKIDATA and p.get("action") == "wbsearchentities":
            hits = {"Hussein of Jordan": ["Q1", "Q2"], "Nobody Known": [], "Gamal Abdel Nasser": ["Q3"]}[p["search"]]
            return FakeResp({"search": [{"id": h} for h in hits]})
        if url == fp.WIKIDATA and p.get("action") == "wbgetentities":
            ents = {"Q1": {"id": "Q1", "claims": {"P31": [{"mainsnak": {"datavalue": {"value": {"id": "Q4167410"}}}}]}},  # a disambiguation page
                    "Q2": human("Q2", "King Hussein 1953.jpg", "Q810", "King of Jordan"),
                    "Q3": human("Q3", "Nasser portrait.jpg", "Q79", "President of Egypt")}
            return FakeResp({"entities": {i: ents[i] for i in p["ids"].split("|")}})
        if url == fp.COMMONS:
            title = p["titles"]
            lic = "Public domain" if "Hussein" in title else "Fair use"
            return FakeResp({"query": {"pages": {"1": {"imageinfo": [{"thumburl": "https://upload.example/" + title, "descriptionurl": "https://commons.example/" + title,
                "extmetadata": {"LicenseShortName": {"value": lic}, "Artist": {"value": "<a href='x'>Royal Court</a>"}}}]}}}})
        if url.startswith("https://upload.example/"):
            return FakeResp(content=self.jpeg)
        raise AssertionError("unexpected request " + url)


class Tests(unittest.TestCase):
    def test_licences(self):
        self.assertTrue(fp.licence_ok("Public domain"))
        self.assertTrue(fp.licence_ok("CC BY-SA 4.0"))
        self.assertFalse(fp.licence_ok("Fair use"))
        self.assertFalse(fp.licence_ok(""))

    def test_scoring_prefers_jordanian_human_with_image(self):
        a = fp.score_candidate(human("Qa", "a.jpg", "Q810", "King of Jordan"), "King from 1952")
        b = fp.score_candidate(human("Qb", "b.jpg", "Q30", "American actor"), "King from 1952")
        c = fp.score_candidate(human("Qc", None, "Q810"), "King")
        self.assertGreater(a, b)
        self.assertLess(c, 0)

    def test_crop_shape_without_face(self):
        img = fp.crop_portrait(Image.new("RGB", (1000, 600), "white"))
        self.assertEqual(img.size, (400, 480))

    def test_full_run_with_fake_wikimedia(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            csv_path = d / "people.csv"
            with open(csv_path, "w", newline="", encoding="utf-8") as f:
                w = csv.DictWriter(f, fieldnames=["id", "name", "search", "qid", "role", "priority", "section"])
                w.writeheader()
                w.writerow({"id": "hussein", "name": "King Hussein", "search": "Hussein of Jordan", "qid": "", "role": "King", "priority": "A", "section": ""})
                w.writerow({"id": "nasser", "name": "Nasser", "search": "Gamal Abdel Nasser", "qid": "", "role": "Egyptian leader", "priority": "A", "section": ""})
                w.writerow({"id": "ghost", "name": "Nobody", "search": "Nobody Known", "qid": "", "role": "", "priority": "B", "section": ""})
            args = SimpleNamespace(out=str(d / "portraits"), csv=str(csv_path), report=str(d / "report.csv"), only="", priority="", force=False, width=600)
            cli = fp.Client("test@example.org", delay=0, session=FakeSession())
            rep = {r["id"]: r for r in fp.run(args, cli)}
            self.assertEqual(rep["hussein"]["status"], "ok")
            self.assertEqual(rep["hussein"]["qid"], "Q2")
            self.assertEqual(rep["nasser"]["status"], "licence not free")
            self.assertEqual(rep["ghost"]["status"], "no match")
            self.assertTrue((d / "portraits" / "hussein.jpg").exists())
            self.assertEqual(Image.open(d / "portraits" / "hussein.jpg").size, (400, 480))
            credits = json.loads((d / "portraits" / "credits.json").read_text(encoding="utf-8"))
            self.assertEqual(credits["hussein"]["artist"], "Royal Court")
            self.assertIn("test@example.org", cli.s.headers["User-Agent"])
            # second run skips files we already have
            rep2 = {r["id"]: r for r in fp.run(args, cli)}
            self.assertEqual(rep2["hussein"]["status"], "already have")


if __name__ == "__main__":
    unittest.main(verbosity=1)
