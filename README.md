# المملكة — Al-Mamlaka

A grand strategy game set in Jordan from 1953, built in Godot 4. The project is in the `game/` folder;
the first prototype (Tauri + TypeScript) is kept in `legacy-web/`.

## Playing

Every push to `main` builds a Windows game on GitHub: open the **Actions** tab, pick the latest run,
and download **AlMamlaka1953-windows** at the bottom. Unzip and run the .exe (Windows may warn that it
is unsigned: *More info → Run anyway*).

Two scenarios are playable from the main menu:

- **الطريق إلى المجلس (Salt, May–June 1953):** a young municipal clerk runs for a council seat.
- **الحلف (Amman, December 1955):** the prime minister's fixer has six days to win the House for the Baghdad Pact.

## Portraits of historical figures

`tools/fetch_portraits.py` downloads free-licence photos of the people in `tools/portraits.csv` from
Wikimedia Commons (found through Wikidata), crops them to the face and records author and licence.
Run it on your own computer:

```
pip install requests pillow opencv-python-headless
python tools/fetch_portraits.py --contact "your email or website"
```

- Photos go to `game/portraits/<id>.jpg`, credits to `game/portraits/credits.json`, and a report of who
  was found (and who needs a manual pick) to `tools/portraits_report.csv`.
- Only free licences are kept (public domain, CC0, CC BY, CC BY-SA, GFDL). Show the credits in the game:
  the main menu's "الصور ومصادرها" screen reads `credits.json`.
- If the wrong person is matched, put the right Wikidata ID in the `qid` column and run
  `python tools/fetch_portraits.py --contact ... --only <id> --force`.
- To see photos without rebuilding, copy the `game/portraits` folder next to the game's .exe.
  To include them in every build, commit `game/portraits/` and push.

## Developing

```
godot --headless --path game res://tests/test.tscn        # 90 playthroughs of the Salt slice
godot --headless --path game res://tests/test_house.tscn  # 80 playthroughs of the parliament scenario
python3 tools/test_fetch_portraits.py                     # portrait downloader, offline
```

Screenshot tours (need a display, or `xvfb-run` on Linux): `godot --path game -- --shots=DIR`,
`-- --pact-shots=DIR`, `-- --menu-shot=FILE.png`; interface smoke test: `-- --autoplay=SECONDS`.
