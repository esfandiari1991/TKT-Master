#!/usr/bin/env python3
"""
TKT Master — Optional Content Crawler (human-in-the-loop)
=========================================================
Fetches text from sources YOU configure and have the right to use (e.g. your own
EduPocket.org pages, or openly/CC-licensed practice material), extracts candidate
glossary terms / practice questions, and writes them to `review_queue.json`.

It does NOT inject anything into the app automatically. You review the queue,
set "approved": true on the items you want, then run:
    python3 engine.py merge-reviewed

Design principles:
  • Only fetches sources explicitly marked  "license_ok": true  in sources.json.
  • Respects robots.txt and uses a polite delay between requests.
  • Standard library only (urllib) — no paid AI/API, fully under your control.
"""
import json, os, re, time, sys
from urllib.request import urlopen, Request
from urllib.parse import urlparse
from urllib.robotparser import RobotFileParser

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCES = os.path.join(HERE, "sources.json")
QUEUE = os.path.join(HERE, "review_queue.json")
UA = "TKTMaster-ContentCrawler/1.0 (+https://www.EduPocket.org)"

def allowed(url):
    try:
        p = urlparse(url); rp = RobotFileParser()
        rp.set_url(f"{p.scheme}://{p.netloc}/robots.txt"); rp.read()
        return rp.can_fetch(UA, url)
    except Exception:
        return False  # if unsure, do NOT fetch

def fetch(url):
    req = Request(url, headers={"User-Agent": UA})
    with urlopen(req, timeout=20) as r:
        html = r.read().decode("utf-8", "ignore")
    text = re.sub(r"(?is)<(script|style).*?>.*?</\1>", " ", html)
    text = re.sub(r"(?s)<[^>]+>", " ", text)
    text = re.sub(r"&nbsp;|&amp;|&#\d+;", " ", text)
    return re.sub(r"[ \t]+", " ", text)

def extract_terms(text):
    out = []
    for m in re.finditer(r"(?m)^\s*([A-Z][A-Za-z /()&'\-]{2,40}):\s*(.{20,300})$", text):
        out.append({"kind": "term", "term": m.group(1).strip(),
                    "definition_en": m.group(2).strip()})
    return out

def extract_qa(text):
    out = []
    # very rough: a line ending in '?' followed by A) B) C) options
    for m in re.finditer(r"([^.?!\n]{12,200}\?)\s+A[\).]\s*([^\n]{1,80})\s+B[\).]\s*([^\n]{1,80})\s+C[\).]\s*([^\n]{1,80})", text):
        out.append({"kind": "qa", "stem": m.group(1).strip(),
                    "options": [m.group(2).strip(), m.group(3).strip(), m.group(4).strip()]})
    return out

def main():
    if not os.path.exists(SOURCES):
        json.dump({"polite_delay_seconds": 4, "sources": [
            {"url": "https://www.EduPocket.org/your-tkt-page", "type": "glossary", "license_ok": False}
        ]}, open(SOURCES, "w"), indent=2)
        print(f"Created template {SOURCES}. Add sources you have rights to and set license_ok:true.")
        return
    cfg = json.load(open(SOURCES)); delay = cfg.get("polite_delay_seconds", 4)
    queue = []
    for s in cfg.get("sources", []):
        if not s.get("license_ok"):
            print(f"skip (license_ok false): {s['url']}"); continue
        if not allowed(s["url"]):
            print(f"skip (robots.txt disallows): {s['url']}"); continue
        try:
            text = fetch(s["url"])
        except Exception as e:
            print(f"fetch failed {s['url']}: {e}"); continue
        items = extract_terms(text) if s.get("type") == "glossary" else extract_qa(text)
        for it in items:
            it.update({"source": s["url"], "approved": False})
            queue.append(it)
        print(f"{s['url']}: {len(items)} candidate item(s)")
        time.sleep(delay)
    json.dump(queue, open(QUEUE, "w", ensure_ascii=False, indent=1), ensure_ascii=False)
    print(f"\nWrote {len(queue)} candidates to review_queue.json.")
    print("Review them, set \"approved\": true on the good ones, then: python3 engine.py merge-reviewed")

if __name__ == "__main__":
    main()
