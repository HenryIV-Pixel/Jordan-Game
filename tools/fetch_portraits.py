"""Download portraits of historical figures from Wikimedia Commons, via Wikidata, for the game.

Run it on your own computer (Windows, macOS or Linux) with Python 3.9+:

    pip install requests pillow opencv-python-headless
    python tools/fetch_portraits.py --contact "your-email-or-site"

What it does for each person in tools/portraits.csv:
  1. finds the person on Wikidata (or uses the "qid" column if you filled it in),
  2. takes their main image (Wikidata property P18) from Wikimedia Commons,
  3. keeps it only if the licence is free (public domain, CC0, CC BY, CC BY-SA, GFDL),
  4. crops it to a 5:6 portrait around the face and saves game/portraits/<id>.jpg,
  5. records the author and licence in game/portraits/credits.json (show these in the game's credits),
  6. writes tools/portraits_report.csv listing who was found and who needs a manual pick.

Wikimedia asks every script to identify itself: --contact is put in the User-Agent header so they can reach
you if the script misbehaves. Requests are spaced out (1 per second by default) to stay polite.

If the wrong person is matched, put the right Wikidata ID (e.g. Q57643) in the "qid" column and run again with
--only <id> --force. People with no free photo are left for us to draw in the game's style.
"""
from __future__ import annotations

import argparse
import csv
import html
import io
import json
import re
import sys
import time
from pathlib import Path

try:
    import requests
except ImportError:  # pragma: no cover
    requests = None

from PIL import Image, ImageOps

try:
    import cv2
    import numpy as np
except ImportError:  # face detection is optional; we fall back to a top-centre crop
    cv2 = None
    np = None

WIKIDATA = "https://www.wikidata.org/w/api.php"
COMMONS = "https://commons.wikimedia.org/w/api.php"
HUMAN = "Q5"
# countries that make a match more likely to be the right person
REGION = {"Q810": 4, "Q796": 2, "Q858": 2, "Q79": 2, "Q851": 1, "Q801": 1, "Q145": 1, "Q30": 1, "Q15180": 1, "Q219060": 2}
FREE_LICENCES = ("public domain", "pd", "cc0", "cc by", "cc-by", "cc by-sa", "cc-by-sa", "gfdl", "attribution")
NOT_FREE = ("fair use", "non-free", "copyrighted", "all rights reserved")

ROOT = Path(__file__).resolve().parent.parent


class Client:
    """Thin wrapper around the two APIs with politeness delay and retries."""

    def __init__(self, contact: str, delay: float = 1.0, session=None):
        if session is None:
            if requests is None:
                sys.exit("Please install requests:  pip install requests pillow opencv-python-headless")
            session = requests.Session()
        self.s = session
        self.s.headers["User-Agent"] = f"JordanStrategyGamePortraitFetcher/1.0 ({contact})"
        self.delay = delay
        self._last = 0.0

    def get(self, url: str, params: dict | None = None, raw: bool = False):
        for attempt in range(5):
            wait = self.delay - (time.time() - self._last)
            if wait > 0:
                time.sleep(wait)
            self._last = time.time()
            r = self.s.get(url, params=params, timeout=30)
            if r.status_code in (429, 500, 502, 503, 504):
                time.sleep(min(60, 2 ** attempt * 3))
                continue
            r.raise_for_status()
            return r.content if raw else r.json()
        raise RuntimeError(f"gave up after retries: {url}")


def claim_ids(entity: dict, prop: str) -> list[str]:
    out = []
    for c in entity.get("claims", {}).get(prop, []):
        v = c.get("mainsnak", {}).get("datavalue", {}).get("value")
        if isinstance(v, dict) and "id" in v:
            out.append(v["id"])
        elif isinstance(v, str):
            out.append(v)
    return out


def score_candidate(entity: dict, role: str) -> float:
    """Higher is a better match. Non-humans and people without an image score below zero."""
    if HUMAN not in claim_ids(entity, "P31"):
        return -10
    if not claim_ids(entity, "P18"):
        return -5
    s = 1.0
    for c in claim_ids(entity, "P27"):
        s += REGION.get(c, 0)
    desc = entity.get("descriptions", {}).get("en", {}).get("value", "").lower()
    for word in re.findall(r"[a-z]{4,}", role.lower()):
        if word in desc:
            s += 0.5
    # born before 1945: our people are 1950s figures
    for c in entity.get("claims", {}).get("P569", []):
        t = c.get("mainsnak", {}).get("datavalue", {}).get("value", {}).get("time", "")
        m = re.match(r"[+-](\d{4})", t)
        if m and int(m.group(1)) < 1945:
            s += 1
    return s


def find_entity(cli: Client, search: str, role: str, qid: str = "") -> dict | None:
    if qid:
        ents = cli.get(WIKIDATA, {"action": "wbgetentities", "ids": qid, "props": "claims|descriptions|labels", "languages": "en|ar", "format": "json"})
        return ents.get("entities", {}).get(qid)
    res = cli.get(WIKIDATA, {"action": "wbsearchentities", "search": search, "language": "en", "type": "item", "limit": 7, "format": "json"})
    ids = [h["id"] for h in res.get("search", [])]
    if not ids:
        return None
    ents = cli.get(WIKIDATA, {"action": "wbgetentities", "ids": "|".join(ids), "props": "claims|descriptions|labels", "languages": "en|ar", "format": "json"})
    best, best_s = None, 0.0
    for i in ids:
        e = ents.get("entities", {}).get(i)
        if not e:
            continue
        sc = score_candidate(e, role) - ids.index(i) * 0.3  # search rank matters a little
        if sc > best_s:
            best, best_s = e, sc
    return best


def strip_html(s: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", s or ""))).strip()


def licence_ok(name: str) -> bool:
    n = (name or "").lower()
    if not n or any(b in n for b in NOT_FREE):
        return False
    return any(n.startswith(f) or f in n for f in FREE_LICENCES)


def image_info(cli: Client, filename: str, width: int = 900) -> dict | None:
    res = cli.get(COMMONS, {"action": "query", "titles": "File:" + filename, "prop": "imageinfo", "iiprop": "url|extmetadata",
                            "iiurlwidth": width, "format": "json"})
    for page in res.get("query", {}).get("pages", {}).values():
        info = (page.get("imageinfo") or [None])[0]
        if not info:
            return None
        meta = info.get("extmetadata", {})
        val = lambda k: meta.get(k, {}).get("value", "")
        return {"url": info.get("thumburl") or info.get("url"), "page": info.get("descriptionurl", ""),
                "licence": strip_html(val("LicenseShortName")), "artist": strip_html(val("Artist")),
                "credit": strip_html(val("Credit")), "usage": strip_html(val("UsageTerms"))}
    return None


def crop_portrait(img: Image.Image, size=(400, 480)) -> Image.Image:
    """Crop to the size's aspect ratio around the largest face, or the top centre when no face is found."""
    img = ImageOps.exif_transpose(img).convert("RGB")
    W, H = img.size
    aspect = size[0] / size[1]
    face = None
    if cv2 is not None and hasattr(cv2, "CascadeClassifier"):
        try:
            gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
            casc = cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_frontalface_default.xml")
            faces = casc.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(max(24, W // 20), max(24, W // 20)))
            if len(faces):
                face = max(faces, key=lambda f: f[2] * f[3])
        except Exception:  # an OpenCV build without face detection: use the plain crop
            face = None
    if face is not None:
        x, y, w, h = [int(v) for v in face]
        ch = min(H, int(h * 2.6))  # head and shoulders
        cw = int(ch * aspect)
        if cw > W:
            cw = W
            ch = int(cw / aspect)
        cx, cy = x + w // 2, y + int(h * 0.62)
        left = max(0, min(W - cw, cx - cw // 2))
        top = max(0, min(H - ch, cy - int(ch * 0.42)))
    else:
        if W / H > aspect:
            ch, cw = H, int(H * aspect)
        else:
            cw, ch = W, int(W / aspect)
        left, top = (W - cw) // 2, 0 if H > ch else (H - ch) // 2
    return img.crop((left, top, left + cw, top + ch)).resize(size, Image.LANCZOS)


def run(args, cli: Client) -> list[dict]:
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    credits_path = out_dir / "credits.json"
    credits = json.loads(credits_path.read_text(encoding="utf-8")) if credits_path.exists() else {}
    report = []
    with open(args.csv, encoding="utf-8") as f:
        people = list(csv.DictReader(f))
    for p in people:
        pid = p["id"]
        if args.only and pid not in args.only.split(","):
            continue
        if args.priority and p.get("priority", "C") > args.priority:
            continue
        target = out_dir / f"{pid}.jpg"
        if target.exists() and not args.force:
            report.append({"id": pid, "name": p["name"], "status": "already have", "qid": credits.get(pid, {}).get("qid", ""), "licence": credits.get(pid, {}).get("licence", ""), "note": ""})
            continue
        row = {"id": pid, "name": p["name"], "status": "", "qid": "", "licence": "", "note": ""}
        try:
            ent = find_entity(cli, p.get("search") or p["name"], p.get("role", ""), p.get("qid", "").strip())
            if not ent:
                row["status"] = "no match"
                row["note"] = "put the Wikidata ID in the qid column"
            else:
                row["qid"] = ent.get("id", "")
                files = claim_ids(ent, "P18")
                if not files:
                    row["status"] = "no image"
                    row["note"] = "no main image on Wikidata; draw in game style or pick a Commons file by hand"
                else:
                    info = image_info(cli, files[0], args.width)
                    if not info or not info.get("url"):
                        row["status"] = "no image"
                    elif not licence_ok(info["licence"]):
                        row["status"] = "licence not free"
                        row["licence"] = info["licence"]
                        row["note"] = info["page"]
                    else:
                        data = cli.get(info["url"], raw=True)
                        crop_portrait(Image.open(io.BytesIO(data))).save(target, "JPEG", quality=90)
                        credits[pid] = {"name": p["name"], "qid": row["qid"], "file": files[0], "page": info["page"], "licence": info["licence"],
                                        "artist": info["artist"], "credit": info["credit"]}
                        row["status"] = "ok"
                        row["licence"] = info["licence"]
        except Exception as e:  # keep going; report the problem
            row["status"] = "error"
            row["note"] = str(e)[:200]
        report.append(row)
        print(f"{row['status']:>16}  {pid}  {row['note']}")
        credits_path.write_text(json.dumps(credits, ensure_ascii=False, indent=1), encoding="utf-8")
    with open(args.report, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["id", "name", "status", "qid", "licence", "note"])
        w.writeheader()
        w.writerows(report)
    ok = sum(1 for r in report if r["status"] in ("ok", "already have"))
    print(f"\n{ok} of {len(report)} portraits ready in {out_dir}. Details: {args.report}")
    return report


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--contact", required=True, help="your email or website, sent to Wikimedia in the User-Agent")
    ap.add_argument("--csv", default=str(ROOT / "tools" / "portraits.csv"))
    ap.add_argument("--out", default=str(ROOT / "game" / "portraits"))
    ap.add_argument("--report", default=str(ROOT / "tools" / "portraits_report.csv"))
    ap.add_argument("--only", default="", help="comma-separated ids to fetch")
    ap.add_argument("--priority", default="", help="only people with this priority or higher (A, B or C)")
    ap.add_argument("--force", action="store_true", help="download again even if the file exists")
    ap.add_argument("--width", type=int, default=900, help="width of the image requested from Commons")
    ap.add_argument("--delay", type=float, default=1.0, help="seconds between requests")
    args = ap.parse_args(argv)
    run(args, Client(args.contact, args.delay))


if __name__ == "__main__":
    main()
