"""
Extract every bout result from the completed 2026 NCAA bracket PDF.

Per-page bout-number arithmetic (weight index k = 0..9 for 125..285):
  pigtail 1+k | champ R1 11+16k..26+16k | R2 171+8k..178+8k | QF 341+4k..344+4k
  SF 501+2k..502+2k | F 631+k | cons pigtail 251+k | cons R1 261+8k..268+8k
  cons R2 381+8k..388+8k | cons R3 461+4k..464+4k | blood 521+4k..524+4k
  cons SF 561+2k..562+2k | cons finals 581+2k..582+2k
  place_7 601+2k | place_5 611+2k | place_3 621+2k

Winner = participant appearing in a later round (progression); victory
type/score from the attached result text.

Output: docs/build/results_2026_ncaa.json
"""
import json
import re

import pypdf

PDF = "2026 NCAA Division I Wrestling Championships_Brackets_Complete.pdf"
OUT = "../docs/build/results_2026_ncaa.json"
WEIGHTS = [125, 133, 141, 149, 157, 165, 174, 184, 197, 285]

ENTRY = re.compile(r"^\((\d{1,2})\)\s*([A-Z][A-Za-z\-\'.` ]+?)\s*\(([A-Z&]{2,6})\)(?:\s+(\d+)-(\d+))?$")
RESULT = re.compile(r"^(Dec|MD|TF-1.5|TF|Fall|SV-1|TB-1|2-OT|OT|Inj\.?|DQ|MFFL|MFF|FF)\b(.*)$", re.I)
BOUT = re.compile(r"^(\d{1,3})$")
GLUE_RES_BOUT = re.compile(r"^((?:Dec|MD|TF-1.5|TF|Fall|SV-1|TB-1|2-OT|OT|Inj\.?|DQ|MFFL|MFF|FF)\b.*?)\s+(\d{3})$", re.I)
GLUE_PLACE_PRE = re.compile(r"^(\d{3})\s*(\(.+)$")
GLUE_PLACE_POST = re.compile(r"^(\(\d{1,2}\)\s*.+?)\s+(\d{3})$")

def bout_map(k):
    m = {1 + k: ("championship", "pigtail"), 631 + k: ("championship", "champ_finals"),
         251 + k: ("consolation", "cons_pigtail"),
         601 + k: ("placement", "place_7"), 611 + k: ("placement", "place_5"), 621 + k: ("placement", "place_3")}
    for i in range(16):
        m[11 + 16 * k + i] = ("championship", "champ_r1")
    for i in range(8):
        m[171 + 8 * k + i] = ("championship", "champ_r2")
        m[261 + 8 * k + i] = ("consolation", "cons_r1")
        m[381 + 8 * k + i] = ("consolation", "cons_r2")
    for i in range(4):
        m[341 + 4 * k + i] = ("championship", "champ_qf")
        m[461 + 4 * k + i] = ("consolation", "cons_r3")
        m[521 + 4 * k + i] = ("consolation", "cons_r4")
    for i in range(2):
        m[501 + 2 * k + i] = ("championship", "champ_sf")
        m[561 + 2 * k + i] = ("consolation", "cons_r5")
        m[581 + 2 * k + i] = ("consolation", "cons_r6")
    return m

def parse_entry(tok):
    m = ENTRY.match(tok)
    if not m:
        return None
    return {"seed": int(m.group(1)), "name": m.group(2).strip(), "school": m.group(3).strip()}

def is_entry(tok):
    return ENTRY.match(tok) is not None

def is_bout(tok):
    return BOUT.match(tok) is not None

def is_result(tok):
    return RESULT.match(tok) is not None

def classify(rt):
    if not rt:
        return None, None
    t = rt.strip()
    m = RESULT.match(t)
    if not m:
        return None, t
    kind = m.group(1).lower().rstrip(".")
    rest = (m.group(2) or "").strip()
    vmap = {
        "dec": "decision", "md": "major", "tf": "tech_fall", "tf-1.5": "tech_fall",
        "fall": "fall", "sv-1": "decision", "tb-1": "decision", "2-ot": "decision",
        "ot": "decision", "inj": "injury_default", "dq": "disqualification",
        "ff": "forfeit", "mff": "medical_forfeit", "mffl": "medical_forfeit",
    }
    return vmap.get(kind), t

def clean_person_name(s):
    """Strip '(SCHOOL)' and record fragments from a raw name string."""
    s = re.sub(r"\([A-Z&]{2,6}\)", "", s or "")
    s = re.sub(r"\s+\d+-\d+$", "", s)
    return s.strip()

def last_token(s):
    parts = re.sub(r"[^a-z ]", "", clean_person_name(name_of(s)).lower()).split()
    return parts[-1] if parts else ""

def same(x, y):
    """Person match: exact normalized, or last-name token equality."""
    nx, ny = clean_person_name(name_of(x)), clean_person_name(name_of(y))
    if not nx or not ny:
        return False
    a, b = nx.lower(), ny.lower()
    if a == b or a.endswith(b) or b.endswith(a):
        return True
    la, lb = last_token(x), last_token(y)
    return bool(la) and la == lb

def name_of(p):
    return (p or {}).get("name", "") if isinstance(p, dict) else (p or "")

def parse_page(text, bmap):
    lines = [ln.strip() for ln in text.split("\n") if ln.strip()]
    bouts = {}
    n = len(lines)
    r1_lo, r1_hi = 11, 26

    def rng(code):
        return {bn for bn, (sec, rc) in bmap.items() if rc == code}

    R1 = rng("champ_r1")
    QUINT = rng("champ_r2") | rng("champ_qf") | rng("champ_sf") | rng("cons_r3") | rng("cons_r4") | rng("cons_r5") | rng("cons_r6")
    CONS_R1 = rng("cons_r1")
    CONS_R2 = rng("cons_r2")
    PLACE = rng("place_3") | rng("place_5") | rng("place_7")
    PIG = rng("pigtail")
    CONS_PIG = rng("cons_pigtail")
    FINAL = rng("champ_finals")

    def put(bn, a, b, prev_res_a=None, prev_res_b=None):
        if bn not in bmap:
            return
        sec, rc = bmap[bn]
        if bn in bouts:
            bouts[bn].update({k: v for k, v in {"a": a, "b": b, "prev_res_a": prev_res_a, "prev_res_b": prev_res_b}.items() if v is not None})
            return
        bouts[bn] = {"a": a, "b": b, "prev_res_a": prev_res_a, "prev_res_b": prev_res_b,
                     "section": sec, "round_code": rc, "result": None, "winner": None}

    for i, tok in enumerate(lines):
        # cons R1 glued: "NameA 269NameB (...)" or "NameA (SCH)322NameB"
        m = re.match(r"^(.+?[a-zA-Z\)])\s*(\d{3})([A-Z].*)$", tok)
        if m and int(m.group(2)) in CONS_R1:
            bn = int(m.group(2))
            put(bn, {"name": clean_person_name(m.group(1))}, {"name": clean_person_name(m.group(3))})
            continue
        # result+bout glued (cons R2): "Dec 6-2 381"
        m = GLUE_RES_BOUT.match(tok)
        if m and int(m.group(2)) in CONS_R2:
            bn = int(m.group(2))
            a = parse_entry(lines[i - 1]) if i >= 1 else None
            b = parse_entry(lines[i + 1]) if i + 1 < n else None
            put(bn, a, b, prev_res_a=m.group(1).strip())
            continue
        # placement glued pre: "611(5) Spratley (OKST)"
        m = GLUE_PLACE_PRE.match(tok)
        if m and int(m.group(1)) in PLACE:
            bn = int(m.group(1))
            a = parse_entry(m.group(2)) or {"name": clean_person_name(m.group(2))}
            b = parse_entry(lines[i + 1]) if i + 1 < n else None
            put(bn, a, b)
            continue
        # placement glued post: "(11) Klinsky (RID) 601"
        m = GLUE_PLACE_POST.match(tok)
        if m and int(m.group(2)) in PLACE:
            bn = int(m.group(2))
            a = parse_entry(m.group(1))
            b = parse_entry(lines[i + 1]) if i + 1 < n and is_entry(lines[i + 1]) else None
            put(bn, a, b)
            continue
        # pigtail: "1 Dec 4-1" or "10 Dec 4-1"
        m = re.match(r"^(\d{1,2})\s+((?:Dec|MD|TF|Fall|SV|TB).*)$", tok, re.I)
        if m and int(m.group(1)) in PIG and i >= 1 and is_entry(lines[i - 1]):
            bn = int(m.group(1))
            b = parse_entry(lines[i + 1]) if i + 1 < n else None
            put(bn, parse_entry(lines[i - 1]), b, prev_res_a=m.group(2).strip())
            continue
        if is_bout(tok):
            bn = int(tok)
            if bn in R1:
                a = parse_entry(lines[i - 1]) if i >= 1 else None
                b = parse_entry(lines[i + 1]) if i + 1 < n else None
                if a and b:
                    put(bn, a, b)
                continue
            if bn in CONS_PIG:
                a = lines[i - 1] if i >= 1 else None
                b = lines[i + 1] if i + 1 < n else None
                put(bn, {"name": clean_person_name(a)}, {"name": clean_person_name(b)})
                continue
            if bn in QUINT:
                a = parse_entry(lines[i - 2]) if i >= 2 else None
                ra = lines[i - 1] if i >= 1 and is_result(lines[i - 1]) else None
                b = parse_entry(lines[i + 1]) if i + 1 < n else None
                rb = lines[i + 2] if i + 2 < n and is_result(lines[i + 2]) else None
                put(bn, a, b, prev_res_a=ra, prev_res_b=rb)
                continue
            if bn in FINAL:
                # quint like other rounds: [E_A, R_A, BOUT, E_B, R_B], then
                # trailing [E_champ, R_champ] = winner + final result
                a = parse_entry(lines[i - 2]) if i >= 2 else None
                ra = lines[i - 1] if i >= 1 and is_result(lines[i - 1]) else None
                b = parse_entry(lines[i + 1]) if i + 1 < n else None
                rb = lines[i + 2] if i + 2 < n and is_result(lines[i + 2]) else None
                put(bn, a, b, prev_res_a=ra, prev_res_b=rb)
                champ = parse_entry(lines[i + 3]) if i + 3 < n and is_entry(lines[i + 3]) else None
                champ_res = lines[i + 4] if i + 4 < n and is_result(lines[i + 4]) else None
                if champ:
                    if same(champ, a):
                        bouts[bn]["winner"] = a
                        bouts[bn]["result"] = champ_res
                    elif same(champ, b):
                        bouts[bn]["winner"] = b
                        bouts[bn]["result"] = champ_res
                continue
            if bn in PLACE:
                a = None
                for back in (1, 2):
                    if i - back >= 0 and is_entry(lines[i - back]):
                        a = parse_entry(lines[i - back])
                        break
                b = parse_entry(lines[i + 1]) if i + 1 < n else None
                put(bn, a, b)
                continue
        # R1 record-glued bout: record ends with bout digits ("20-515" or "23-5 111")
        m = re.match(r"^(\(\d{1,2}\)\s*[A-Z][A-Za-z\-\'.` ]+?\s*\([A-Z&]{2,6}\))\s*(\d+)-(\d+)\s*(\d{2,3})?$", tok)
        if m:
            rec = m.group(3)
            space_bout = m.group(4)
            if space_bout and int(space_bout) in R1:
                bn = int(space_bout)
                if bn not in bouts and i + 1 < n and is_entry(lines[i + 1]):
                    put(bn, parse_entry(m.group(1)), parse_entry(lines[i + 1]))
                continue
            for cut in (1, 2):
                if rec[cut:].isdigit() and int(rec[cut:]) in R1:
                    bn = int(rec[cut:])
                    if bn not in bouts and i + 1 < n and is_entry(lines[i + 1]):
                        put(bn, parse_entry(m.group(1)), parse_entry(lines[i + 1]))
                    break
    return bouts

def winner_dest(bn, bmap):
    """The match number that bn's WINNER advances to (real NCAA structure)."""
    k = next((i for i in range(10) if bn in bout_map(i)), None)
    if k is None:
        return None
    sec, rc = bmap[bn]
    if rc == "pigtail":
        return 11 + 16 * k  # feeds champ_r1 #1
    if rc == "champ_r1":
        o = bn - (11 + 16 * k)
        return 171 + 8 * k + o // 2
    if rc == "champ_r2":
        o = bn - (171 + 8 * k)
        return 341 + 4 * k + o // 2
    if rc == "champ_qf":
        o = bn - (341 + 4 * k)
        return 501 + 2 * k + o // 2
    if rc == "champ_sf":
        return 631 + k
    if rc == "cons_pigtail":
        return 261 + 8 * k + 4  # cons_r1 #5
    if rc == "cons_r1":
        o = bn - (261 + 8 * k)
        return 381 + 8 * k + o
    if rc == "cons_r2":
        o = bn - (381 + 8 * k)
        return 461 + 4 * k + o // 2
    if rc == "cons_r3":
        o = bn - (461 + 4 * k)
        return 521 + 4 * k + o
    if rc == "cons_r4":
        o = bn - (521 + 4 * k)
        return 561 + 2 * k + o // 2
    if rc == "cons_r5":
        o = bn - (561 + 2 * k)
        return 581 + 2 * k + o
    if rc == "cons_r6":
        return 621 + k
    return None

def resolve(bouts, bmap):
    for bn, rec in bouts.items():
        a, b = rec.get("a"), rec.get("b")
        if not a or not b:
            continue
        dest = winner_dest(bn, bmap)
        if not dest or dest not in bouts:
            continue
        nrec = bouts[dest]
        for slot in ("a", "b"):
            p = nrec.get(slot)
            if not p:
                continue
            res = nrec.get(f"prev_res_{slot}")
            if same(p, a):
                rec["winner"] = a
                rec["result"] = rec.get("result") or res
                break
            if same(p, b):
                rec["winner"] = b
                rec["result"] = rec.get("result") or res
                break
    # structural fill: placements derive from cons_r5/cons_r6 outcomes
    def loser(rec):
        if not rec or not rec.get("winner"):
            return None
        a, b, w = rec.get("a"), rec.get("b"), rec.get("winner")
        return b if same(w, a) else a

    for k in range(10):
        r5a, r5b = 561 + 2 * k, 562 + 2 * k
        r6a, r6b = 581 + 2 * k, 582 + 2 * k
        p7, p5, p3 = 601 + k, 611 + k, 621 + k
        if p7 in bouts and bouts[p7].get("a") is None:
            bouts[p7]["a"] = loser(bouts.get(r5a))
            bouts[p7]["b"] = loser(bouts.get(r5b))
        if p5 in bouts and bouts[p5].get("a") is None:
            bouts[p5]["a"] = loser(bouts.get(r6a))
            bouts[p5]["b"] = loser(bouts.get(r6b))
        if p3 in bouts and bouts[p3].get("a") is None:
            bouts[p3]["a"] = bouts.get(r6a, {}).get("winner")
            bouts[p3]["b"] = bouts.get(r6b, {}).get("winner")
        # placements: assign structurally (glue parsing mis-assigns sides)
        if p7 in bouts:
            bouts[p7]["a"] = loser(bouts.get(r5a))
            bouts[p7]["b"] = loser(bouts.get(r5b))
        if p5 in bouts:
            bouts[p5]["a"] = loser(bouts.get(r6a))
            bouts[p5]["b"] = loser(bouts.get(r6b))
        if p3 in bouts:
            bouts[p3]["a"] = bouts.get(r6a, {}).get("winner")
            bouts[p3]["b"] = bouts.get(r6b, {}).get("winner")
    return bouts

def validate(bouts, bmap):
    errs = []
    for bn in sorted(bmap.keys()):
        if bn not in bouts:
            errs.append(f"bout {bn} missing")
            continue
        rec = bouts[bn]
        if not rec.get("a") or not rec.get("b"):
            errs.append(f"bout {bn} ({bmap[bn][1]}) incomplete: {name_of(rec.get('a'))} vs {name_of(rec.get('b'))}")
        elif not rec.get("winner"):
            errs.append(f"bout {bn} ({bmap[bn][1]}) winner unresolved: {name_of(rec['a'])} vs {name_of(rec['b'])}")
    return errs

def main():
    reader = pypdf.PdfReader(PDF)
    out = {}
    for k, page in enumerate(reader.pages):
        text = page.extract_text() or ""
        weight = int(re.search(r"(\d{3}) CHAMPIONSHIP", text.split("\n")[0]).group(1))
        bmap = bout_map(k)
        bouts = resolve(parse_page(text, bmap), bmap)
        errs = validate(bouts, bmap)
        summary = {}
        for bn, rec in sorted(bouts.items()):
            vtype, score = classify(rec.get("result"))
            sec, rc = bmap[bn]
            w = rec.get("winner")
            summary[str(bn)] = {
                "round_code": rc, "section": sec,
                "a": rec.get("a"), "b": rec.get("b"),
                "winner": name_of(w) or None,
                "winner_seed": w.get("seed") if isinstance(w, dict) else None,
                "victory_type": vtype, "score": score,
            }
        out[weight] = summary
        print(f"{weight}: {len(bouts)} bouts, {len(errs)} anomalies")
        for e in errs[:10]:
            print("   !!", e)
    with open(OUT, "w") as f:
        json.dump(out, f, indent=1)
    print("written", OUT)

if __name__ == "__main__":
    main()
