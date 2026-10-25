"""Build assets/lexicon/en.v1.json.gz from ECDICT (MIT, Copyright (c) 2025
Linwei, https://github.com/skywind3000/ECDICT).

Keeps, per headword: frequency rank (COCA `frq`, else BNC `bnc`), exam-tag
bits and a short Chinese gloss; plus inflection -> lemma links and common
multi-word phrases. Usage:
  python3 tools/build_lexicon.py ~/TinglangBench/data/ecdict/ecdict.csv
"""
import csv, gzip, json, re, sys

TAGS = {"zk": 1, "gk": 2, "cet4": 4, "cet6": 8, "ky": 16, "ielts": 32, "toefl": 64, "gre": 128}
WORD = re.compile(r"^[a-z][a-z'\-]*$")
PHRASE = re.compile(r"^[a-z][a-z'\-]*( [a-z][a-z'\-]*){1,3}$")
# Phrasal verbs ("show up", "come up with"): ECDICT rarely marks them as
# Collins/Oxford entries, but they are core spoken English.
PARTICLES = {"up", "down", "out", "off", "on", "in", "over", "away", "back", "through", "together", "around", "into", "along", "apart"}
PHRASAL = re.compile(r"^[a-z]+ (%s)( (with|to|for|on|of|from|at))?$" % "|".join(sorted(PARTICLES)))

def gloss(text):
    lines = [l.strip() for l in text.replace("\\n", "\n").split("\n") if l.strip()]
    lines = [l for l in lines if not l.startswith("[")]  # drop domain-only senses like [计]
    out = "；".join(lines[:2])
    return out[:48]

words, lemmas, phrases, phrasal = {}, {}, {}, []
with open(sys.argv[1], newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        w = row["word"].strip()
        lw = w.lower()
        frq = int(row["frq"] or 0); bnc = int(row["bnc"] or 0)
        rank = frq or bnc
        tags = 0
        for t in (row["tag"] or "").split():
            tags |= TAGS.get(t, 0)
        g = gloss(row["translation"] or "")
        for part in (row["exchange"] or "").split("/"):
            # Forms listed on the base word: p past, d participle, i -ing,
            # 3 third person, s plural, r comparative, t superlative.
            if part[:2] in ("p:", "d:", "i:", "3:", "s:", "r:", "t:") and WORD.match(lw):
                form = part[2:].strip().lower()
                if form and form != lw and WORD.match(form):
                    lemmas.setdefault(form, lw)
            if part.startswith("0:") and WORD.match(lw):
                lemma = part[2:].strip().lower()
                if lemma and lemma != lw and WORD.match(lemma):
                    lemmas[lw] = lemma
        if w != lw and not WORD.match(w.lower()):
            continue
        if WORD.match(lw) and w == lw and (rank or tags) and (rank == 0 or rank <= 60000) and g:
            words[lw] = [rank, tags, g]
        elif PHRASE.match(lw) and w == lw and g and (int(row["collins"] or 0) > 0 or row["oxford"] == "1" or tags):
            phrases[lw] = g
        elif PHRASAL.match(lw) and w == lw and g:
            phrasal.append((lw, g))

lemmas = {k: v for k, v in lemmas.items() if v in words}
# Keep phrasal verbs whose verb is a reasonably common word (rank <= 8000).
for lw, g in phrasal:
    verb = words.get(lw.split(" ")[0])
    if verb and 0 < verb[0] <= 8000:
        phrases.setdefault(lw, g)
data = {"meta": {"source": "ECDICT", "license": "MIT, Copyright (c) 2025 Linwei", "url": "https://github.com/skywind3000/ECDICT",
                  "tags": TAGS, "fields": ["rank", "tags", "zh"]},
        "w": words, "l": lemmas, "p": phrases}
raw = json.dumps(data, ensure_ascii=False, separators=(",", ":")).encode()
with gzip.open("assets/lexicon/en.v1.json.gz", "wb", compresslevel=9) as out:
    out.write(raw)
print(f"words {len(words)}  lemmas {len(lemmas)}  phrases {len(phrases)}  raw {len(raw)/1e6:.1f} MB")
