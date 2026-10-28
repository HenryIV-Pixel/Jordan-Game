"""Offline checks for the Victoria 3 sub-mod (cannot replace the game's error.log, but catches the common mistakes).

Usage: python tools/check_vic3_mod.py vic3-mod/jordan_1950
Checks: balanced braces and quotes, localisation encoding and header, every referenced
localisation key / event id / modifier exists, journal entries have names and reasons.
"""
import re
import sys
from pathlib import Path


def strip_comments(text):
    out = []
    for line in text.splitlines():
        res, in_str = "", False
        for ch in line:
            if ch == '"':
                in_str = not in_str
            if ch == "#" and not in_str:
                break
            res += ch
        out.append(res)
    return "\n".join(out)


def main(root):
    root = Path(root)
    errors = []
    scripts = {p: strip_comments(p.read_text(encoding="utf-8-sig")) for p in list(root.glob("common/**/*.txt")) + list(root.glob("events/**/*.txt"))}
    for p, t in scripts.items():
        depth = 0
        for i, line in enumerate(t.splitlines(), 1):
            if line.count('"') % 2:
                errors.append(f"{p}:{i}: odd number of quotes")
            depth += line.count("{") - line.count("}")
            if depth < 0:
                errors.append(f"{p}:{i}: closing brace without opening")
                depth = 0
        if depth:
            errors.append(f"{p}: {depth} unclosed brace(s)")

    loc = {}
    for p in root.glob("localization/**/*.yml"):
        raw = p.read_bytes()
        if not raw.startswith(b"\xef\xbb\xbf"):
            errors.append(f"{p}: must be UTF-8 with BOM")
        lang = p.parent.name
        if not p.stem.endswith(f"_l_{lang}"):
            errors.append(f"{p}: file name must end in _l_{lang}.yml")
        lines = raw.decode("utf-8-sig").splitlines()
        if not lines or lines[0].strip() != f"l_{lang}:":
            errors.append(f"{p}: first line must be l_{lang}:")
        for i, line in enumerate(lines[1:], 2):
            if not line.strip():
                continue
            m = re.match(r'^ ([\w.\-]+):\d* "(.*)"\s*$', line)
            if not m:
                errors.append(f"{p}:{i}: malformed line")
                continue
            if m.group(1) in loc:
                errors.append(f"{p}:{i}: duplicate key {m.group(1)}")
            loc[m.group(1)] = m.group(2)

    allt = "\n".join(scripts.values())
    events = set(re.findall(r"^(\w+\.\d+)\s*=\s*\{", allt, re.M))
    for e in re.findall(r"id\s*=\s*(\w+\.\d+)", allt):
        if e not in events:
            errors.append(f"trigger_event to missing event {e}")
    mods_txt = "\n".join(t for p, t in scripts.items() if "modifiers" in p.parts)
    modifiers = set(re.findall(r"^(\w+)\s*=\s*\{", mods_txt, re.M))
    for m in re.findall(r"add_modifier\s*=\s*\{\s*name\s*=\s*(\w+)", allt) +re.findall(r"(?:remove_modifier|has_modifier)\s*=\s*(\w+)", allt):
        if m not in modifiers:
            errors.append(f"modifier {m} is used but not defined")
    for m in modifiers:
        if m not in loc:
            errors.append(f"modifier {m} has no localisation")
    for k in re.findall(r"(?:title|desc|flavor|name)\s*=\s*(jor\.\d+\.\w+)", allt):
        if k not in loc:
            errors.append(f"missing localisation {k}")
    je_txt = "\n".join(t for p, t in scripts.items() if "journal_entries" in p.parts)
    for je in re.findall(r"^(\w+)\s*=\s*\{", je_txt, re.M):
        for k in (je, je + "_reason"):
            if k not in loc:
                errors.append(f"missing localisation {k}")
    dec_txt = "\n".join(t for p, t in scripts.items() if "decisions" in p.parts)
    for d in re.findall(r"^(\w+)\s*=\s*\{", dec_txt, re.M):
        for k in (d, d + "_desc"):
            if k not in loc:
                errors.append(f"missing localisation {k}")
    eff_txt = "\n".join(t for p, t in scripts.items() if "scripted_effects" in p.parts)
    effects = set(re.findall(r"^(\w+)\s*=\s*\{", eff_txt, re.M))
    for e in set(re.findall(r"\b(jor_(?:please|anger|crush|relations))\s*=", allt)):
        if e not in effects:
            errors.append(f"scripted effect {e} is used but not defined")

    for e in errors:
        print("ERROR", e)
    print(f"{len(scripts)} script files, {len(loc)} localisation keys, {len(events)} events, {len(modifiers)} modifiers: "
          + ("OK" if not errors else f"{len(errors)} problem(s)"))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "vic3-mod/jordan_1950"))
