# TKT Master — Autonomous Content Engine

Grow the app's content over time with **no dependency on any paid AI, API, or platform**.
Everything here is plain Python (standard library; PyMuPDF only for PDF import) and works
directly on the app's JSON in `../Resources`. This is the "scaffolding" that makes the
content database extensible — the app keeps getting richer just by re-running the engine
and rebuilding.

## Everyday use
```bash
cd content_engine

python3 engine.py stats          # how much content there is
python3 engine.py validate       # check all JSON + that every mock question exists
python3 engine.py regenerate     # rebuild the big auto-question bank + 80-Q mocks
                                 #   from OWNED data (glossary + unit key-concepts).
                                 #   Hand-authored questions are always kept.
```
Then rebuild the app:
```bash
cd .. && ./build.sh
```

## Add new material
```bash
# Import a glossary-style PDF you own (Term: definition):
python3 engine.py import-glossary "/path/to/glossary.pdf"

# Merge questions from a JSON file ([{...}] or {"questions":[...]}):
python3 engine.py add-question my_new_questions.json
```

## Optional crawler (the "fetch more" idea) — human‑in‑the‑loop
The crawler only touches sources **you** list and mark `license_ok: true` in
`sources.json`, respects `robots.txt`, and writes candidates to `review_queue.json`.
**Nothing is added to the app automatically.**
```bash
python3 crawler.py               # creates sources.json on first run; then fetches
# review review_queue.json, set "approved": true on the items you want, then:
python3 engine.py merge-reviewed
cd .. && ./build.sh
```

> ⚖️ Only crawl content you own or that is openly/CC‑licensed (e.g. your own
> EduPocket.org pages). Do not scrape copyrighted exam material.

## Recommended cadence
Every couple of weeks: drop new PDFs in, run `import-glossary`, run `regenerate`,
`validate`, then `build.sh` — the question bank and mocks grow automatically.
