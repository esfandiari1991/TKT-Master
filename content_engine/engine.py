#!/usr/bin/env python3
"""
TKT Master — Autonomous Content Engine
======================================
A self-contained, OFFLINE tool to grow the app's content with NO dependency on
any paid AI / API / platform. It works directly on the app's JSON databases in
../Resources and follows the same schema the app reads.

Commands:
  stats                 Show counts (units, glossary, questions, mocks).
  validate              Validate every JSON file + check mock references resolve.
  regenerate            Rebuild the auto-generated question bank from OWNED data
                        (glossary + unit key-concepts) and rebuild 80-Q mocks.
                        Hand-authored questions (ids starting m1/m2/m3) are kept.
  import-glossary PDF   Extract "Term: definition" / "Term pos\\ndef" entries from a
                        PDF you own and merge new terms into glossary.json
                        (needs PyMuPDF: pip install pymupdf).
  add-question FILE     Merge questions from a JSON file (a list or {"questions":[...]})
                        into questions.json (delegates IDs, skips duplicates).
  merge-reviewed        Merge crawler items you APPROVED in review_queue.json
                        (only entries with "approved": true).

This is the "scaffolding" that lets the content keep growing over time
(the "fetch more" idea) without rebuilding the app from scratch — just re-run
the engine, then `./build.sh`.
"""
import json, os, re, random, sys, argparse

HERE = os.path.dirname(os.path.abspath(__file__))
RES  = os.path.normpath(os.path.join(HERE, "..", "Resources"))
K = ["A", "B", "C", "D"]

def load(name):
    with open(os.path.join(RES, name), encoding="utf-8") as f:
        return json.load(f)

def save(name, data):
    with open(os.path.join(RES, name), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)

def unit_module_map():
    curr = load("curriculum.json"); m = {}
    for mod in curr["modules"]:
        for p in mod["parts"]:
            for u in p["units"]:
                m[u["id"]] = mod["number"]
    return m

# ---------------------------------------------------------------- stats
def cmd_stats(_):
    u = load("units.json")["units"]; g = load("glossary.json")["terms"]
    q = load("questions.json")["questions"]; t = load("mocktests.json")["tests"]
    print(f"units:      {len(u)}  (with sections: {sum(1 for x in u if x['sections'])}, "
          f"with key_concepts: {sum(1 for x in u if x.get('key_concepts'))})")
    print(f"glossary:   {len(g)} terms")
    print(f"questions:  {len(q)}  (hand: {sum(1 for x in q if x['id'][:2] in ('m1','m2','m3'))}, "
          f"generated: {sum(1 for x in q if x['id'][:2] not in ('m1','m2','m3'))})")
    print(f"mock tests: {len(t)}")

# ---------------------------------------------------------------- validate
def cmd_validate(_):
    ok = True
    for name in ["curriculum.json","units.json","glossary.json","questions.json","mocktests.json","extras.json"]:
        try:
            load(name); print(f"  OK  {name}")
        except Exception as e:
            ok = False; print(f"  BAD {name}: {e}")
    qids = {q["id"] for q in load("questions.json")["questions"]}
    try:
        qids |= {q["id"] for q in load("celta.json")["questions"]}
    except Exception:
        pass
    for t in load("mocktests.json")["tests"]:
        missing = [i for i in t["question_ids"] if i not in qids]
        if missing:
            ok = False; print(f"  ! mock '{t['id']}' references {len(missing)} missing question(s): {missing[:5]}")
    print("VALID" if ok else "PROBLEMS FOUND")
    sys.exit(0 if ok else 1)

# ---------------------------------------------------------------- regenerate
STOP = {"TKT","From","Taught by","Viewed as","CLIL exposure","Language syllabus"}
def _good(t):
    term = t["term"]
    return (3 <= len(term) <= 40 and term not in STOP and re.match(r"^[A-Za-z]", term)
            and len(t.get("definition_en","")) >= 25 and not re.search(r"\d", term))

def cmd_regenerate(args):
    random.seed(args.seed)
    gloss = load("glossary.json")["terms"]; units = load("units.json")["units"]
    um = unit_module_map()
    qf = load("questions.json")
    hand = [q for q in qf["questions"] if q["id"][:2] in ("m1","m2","m3")]
    usable = [t for t in gloss if _good(t)]; pool = [t["term"] for t in usable]
    gen = []
    sample = usable[:]; random.shuffle(sample); sample = sample[:args.glossary]
    for i, t in enumerate(sample):
        c = t["term"]; ds = random.sample([x for x in pool if x.lower()!=c.lower()], 3)
        opts = [c]+ds; random.shuffle(opts)
        gen.append({"id":f"gl{i}","module":0,"unit":0,"type":"mcq","difficulty":2,
            "stem_en":"Which term matches this definition?","stem_fa":"کدام اصطلاح با این تعریف مطابقت دارد؟",
            "passage":t["definition_en"],
            "options":[{"key":K[j],"text_en":opts[j],"text_fa":opts[j]} for j in range(4)],
            "answer":[K[opts.index(c)]],"key_terms":[c],
            "explanation_en":f"The definition describes “{c}”. The other options are different ELT terms.",
            "explanation_fa":f"این تعریف، «{c}» را توصیف می‌کند؛ گزینه‌های دیگر اصطلاحاتِ متفاوتی هستند."})
    ci = 0
    for u in units:
        mod = um.get(u["id"], 0)
        for c in u.get("key_concepts", []):
            term = c["term"]; ds = random.sample([x for x in pool if x.lower()!=term.lower()], 3)
            opts = [term]+ds; random.shuffle(opts)
            gen.append({"id":f"cg{ci}","module":mod,"unit":u["id"],"type":"mcq","difficulty":2,
                "stem_en":"Which term matches this definition?","stem_fa":"کدام اصطلاح با این تعریف مطابقت دارد؟",
                "passage":c["gloss_en"],
                "options":[{"key":K[j],"text_en":opts[j],"text_fa":opts[j]} for j in range(4)],
                "answer":[K[opts.index(term)]],"key_terms":[term],
                "explanation_en":f"This defines “{term}”.","explanation_fa":f"این تعریفِ «{term}» است. ({c['gloss_fa']})"}); ci+=1
            exs = c.get("examples") or []
            if exs:
                others = list(dict.fromkeys(
                    e for u2 in units for c2 in u2.get("key_concepts",[]) if c2["term"]!=term for e in (c2.get("examples") or [])))
                if len(others) >= 3:
                    dd = random.sample(others, 3); opts = [exs[0]]+dd; random.shuffle(opts)
                    gen.append({"id":f"ex{ci}","module":mod,"unit":u["id"],"type":"mcq","difficulty":2,
                        "stem_en":f"Which is an example of “{term}”?","stem_fa":f"کدام نمونه‌ای از «{term}» است؟",
                        "options":[{"key":K[j],"text_en":opts[j],"text_fa":opts[j]} for j in range(4)],
                        "answer":[K[opts.index(exs[0])]],"key_terms":[term],
                        "explanation_en":f"“{exs[0]}” is an example of {term}.","explanation_fa":f"«{exs[0]}» نمونه‌ای از {term} است."}); ci+=1
    allq = hand + gen
    qf["questions"] = allq; save("questions.json", qf)
    # rebuild 80-Q mocks (keep any non full-* / non comprehensive tests)
    mt = load("mocktests.json")
    keep = [t for t in mt["tests"] if not t["id"].startswith("full-")]
    by = {1:[],2:[],3:[]}
    for q in allq:
        if q["module"] in by: by[q["module"]].append(q["id"])
    glpool = [q["id"] for q in gen if q["module"]==0]
    def mk(mod):
        ids = by[mod][:]; random.shuffle(ids)
        if len(ids) < 80: ids += random.sample([x for x in glpool if x not in ids], 80-len(ids))
        return ids[:80]
    titles = {1:("Module 1 — Full Mock (80 Q)","ماژول ۱ — آزمون کامل (۸۰ سؤال)"),
              2:("Module 2 — Full Mock (80 Q)","ماژول ۲ — آزمون کامل (۸۰ سؤال)"),
              3:("Module 3 — Full Mock (80 Q)","ماژول ۳ — آزمون کامل (۸۰ سؤال)")}
    full = [{"id":f"full-m{mod}","title_en":titles[mod][0],"title_fa":titles[mod][1],
             "module":mod,"time_limit_minutes":72,"question_ids":mk(mod)} for mod in (1,2,3)]
    full.append({"id":"full-comprehensive-80","title_en":"Comprehensive Full Mock (80 Q)",
                 "title_fa":"آزمون کاملِ جامع (۸۰ سؤال)","module":0,"time_limit_minutes":72,
                 "question_ids":random.sample([q["id"] for q in allq], 80)})
    mt["tests"] = full + keep; save("mocktests.json", mt)
    print(f"regenerated: hand {len(hand)} + generated {len(gen)} = {len(allq)} questions; "
          f"{len(mt['tests'])} mock tests")

# ---------------------------------------------------------------- import glossary pdf
def cmd_import_glossary(args):
    try:
        import fitz
    except ImportError:
        print("PyMuPDF needed: pip install pymupdf"); sys.exit(1)
    d = fitz.open(args.pdf); txt = "\n".join(p.get_text() for p in d)
    lines = [l.strip() for l in txt.split("\n")]
    rgx = re.compile(r"^([A-Z][A-Za-z0-9 /()&'\-]{1,44}):\s*(.*)$")
    found = []; cur = None
    for s in lines:
        if not s: continue
        m = rgx.match(s)
        if m and 1 <= len(m.group(1).split()) <= 5:
            cur = {"term":m.group(1).strip(),"pos":"","definition_en":m.group(2).strip(),
                   "definition_fa":"","see":[],"source":os.path.basename(args.pdf)}
            found.append(cur)
        elif cur:
            cur["definition_en"] = (cur["definition_en"]+" "+s).strip()
    found = [e for e in found if len(e["definition_en"]) >= 15]
    g = load("glossary.json"); have = {t["term"].lower() for t in g["terms"]}; added = 0
    for e in found:
        if e["term"].lower() not in have:
            g["terms"].append(e); have.add(e["term"].lower()); added += 1
    g["terms"].sort(key=lambda e: e["term"].lower()); g["meta"]["count"] = len(g["terms"])
    save("glossary.json", g)
    print(f"imported {len(found)} candidate terms; added {added} new; glossary now {len(g['terms'])}")

# ---------------------------------------------------------------- add questions
def cmd_add_question(args):
    data = json.load(open(args.file, encoding="utf-8"))
    incoming = data["questions"] if isinstance(data, dict) else data
    qf = load("questions.json"); have = {q["id"] for q in qf["questions"]}; added = 0
    for q in incoming:
        if q.get("id") and q["id"] not in have:
            qf["questions"].append(q); have.add(q["id"]); added += 1
    save("questions.json", qf)
    print(f"added {added} question(s); total {len(qf['questions'])}")

# ---------------------------------------------------------------- merge reviewed (crawler output)
def cmd_merge_reviewed(_):
    path = os.path.join(HERE, "review_queue.json")
    if not os.path.exists(path):
        print("no review_queue.json — run crawler.py first"); return
    items = json.load(open(path, encoding="utf-8"))
    approved = [i for i in items if i.get("approved")]
    qf = load("questions.json"); have = {q["id"] for q in qf["questions"]}; added = 0
    for it in approved:
        q = it.get("question")
        if q and q.get("id") and q["id"] not in have:
            qf["questions"].append(q); have.add(q["id"]); added += 1
    save("questions.json", qf)
    print(f"merged {added} approved item(s); total {len(qf['questions'])}")

def main():
    ap = argparse.ArgumentParser(description="TKT Master autonomous content engine (offline).")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("stats").set_defaults(func=cmd_stats)
    sub.add_parser("validate").set_defaults(func=cmd_validate)
    rg = sub.add_parser("regenerate"); rg.add_argument("--seed", type=int, default=42)
    rg.add_argument("--glossary", type=int, default=380); rg.set_defaults(func=cmd_regenerate)
    ig = sub.add_parser("import-glossary"); ig.add_argument("pdf"); ig.set_defaults(func=cmd_import_glossary)
    aq = sub.add_parser("add-question"); aq.add_argument("file"); aq.set_defaults(func=cmd_add_question)
    sub.add_parser("merge-reviewed").set_defaults(func=cmd_merge_reviewed)
    args = ap.parse_args(); args.func(args)

if __name__ == "__main__":
    main()
