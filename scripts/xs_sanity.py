"""Cheap XanoScript sanity scan: brace/paren/bracket balance + risky patterns."""
import glob
import re
import sys

def strip_noise(text):
    # remove // comments (naive but fine outside strings for balance counting)
    text = re.sub(r"//[^\n]*", "", text)
    # blank out string contents
    text = re.sub(r'"(\\.|[^"\\])*"', '""', text)
    text = re.sub(r"'(\\.|[^'\\])*'", "''", text)
    # backtick expressions
    text = re.sub(r"`[^`]*`", "``", text)
    return text

def scan(path):
    raw = open(path, encoding="utf-8").read()
    t = strip_noise(raw)
    issues = []
    bal = t.count("{") - t.count("}")
    par = t.count("(") - t.count(")")
    brk = t.count("[") - t.count("]")
    if bal or par or brk:
        issues.append(f"UNBALANCED braces:{bal:+d} parens:{par:+d} brackets:{brk:+d}")
    # risky filters/statements
    risky = [
        (r"\bset_ifnotnull\b", "set_ifnotnull"),
        (r"\bstarts_with\b", "starts_with"),
        (r"\bincludes\?", "includes?"),
        (r"itemsTotal", "itemsTotal"),
        (r"db\.del\b", "db.del"),
        (r"\|\s*in\s*:", "|in:"),
        (r"create_attachment", "create_attachment"),
        (r"\?\s*\"[^\"]+\"\s*:\s*", "ternary-outside-backtick"),
    ]
    for pat, name in risky:
        if re.search(pat, raw):
            issues.append(f"uses {name}")
    return issues

targets = sys.argv[1:] or sorted(glob.glob("apis/**/*.xs", recursive=True) + glob.glob("functions/**/*.xs", recursive=True) + glob.glob("tasks/*.xs") + glob.glob("tables/*.xs"))
bad = 0
for f in targets:
    iss = scan(f)
    if iss:
        bad += 1
        print(("BAD " if any("UNBALANCED" in i for i in iss) else "warn") + " " + f)
        for i in iss:
            print("     - " + i)
print(f"\n{len(targets)} files scanned, {bad} with findings")

def trace(path):
    raw = open(path, encoding="utf-8").read()
    t = strip_noise(raw)
    bal = 0
    for i, line in enumerate(t.split("\n"), 1):
        bal += line.count("{") - line.count("}")
        if bal < 0:
            print(f"NEGATIVE at line {i}: {line.strip()[:100]}")
            return
    print("final balance:", bal)

if __name__ == "__main__" and len(sys.argv) == 2 and sys.argv[1].endswith(".xs"):
    trace(sys.argv[1])
