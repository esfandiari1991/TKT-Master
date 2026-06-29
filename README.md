# TKT Master 🎓

**A free, fully‑offline native macOS app to prepare for the Cambridge TKT (Teaching Knowledge Test) — Modules 1, 2 & 3.**

Built and maintained by **[EduPocket.org](https://www.EduPocket.org)**.

![TKT Master icon](Resources/icon_preview.png)

---

## ✨ Features
- **All 3 modules, all 33 units** — full bilingual lessons (English + Persian support), the way *The TKT Course* is organised.
- **Rich Key Terms** — every term with sub‑branches, examples, and one‑tap **pronunciation** (British / American, offline).
- **Practice & Mock Tests** — exam‑style multiple‑choice & matching questions, each with a full explanation of *why* every option is right or wrong. Timed mock tests with a predicted band (timing 10% tighter than the real exam, to make you stronger).
- **Glossary (738 terms)** — searchable; tap any term for a full mini‑lesson with examples, cross‑references and related questions.
- **Smart Review** — the app remembers what you get wrong and builds focused review sessions.
- **Optional ambient study music + sound effects** — calm, generative, fully offline. (You can also drop your own track at `~/Music/TKTMaster-study.mp3`.)
- **100% offline & self‑contained** — no account, no subscription, no internet needed. Your progress stays on your Mac.

## ⬇️ Download & Install
1. Download `TKT-Master-macOS.zip` from the **[Releases](../../releases)** page and unzip it.
2. Move **TKT Master.app** to your Applications folder.
3. The first time, **right‑click the app → Open → Open** (this app is not yet notarised with a paid Apple Developer ID, so macOS shows a one‑time "unidentified developer" prompt). After that it opens normally.

> Requires macOS 14 (Sonoma) or later. Universal binary — runs natively on both Apple Silicon and Intel Macs.

## 🛠 Build from source
```bash
git clone <this-repo>
cd TKTMaster
./build.sh            # compiles a universal binary with swiftc, no Xcode/sudo needed
open "build/TKT Master.app"
```

## ⚖️ Disclaimer
TKT Master is an **independent** study app built on the publicly available Cambridge English TKT syllabus and glossary terminology. It is **not affiliated with, endorsed by, or sponsored by** Cambridge University Press & Assessment. "TKT" and "Cambridge" are trademarks of their respective owners.

## 📫 More
Made with care by **[EduPocket.org](https://www.EduPocket.org)** — durable, offline learning tools you own.

---

### فارسی
**TKT Master** یک اپ نیتیو و کاملاً آفلاینِ مک برای آمادگیِ آزمون TKT کمبریج (ماژول‌های ۱، ۲ و ۳) است — رایگان، بدون اشتراک و بدون نیاز به اینترنت. شاملِ درسنامهٔ کاملِ هر ۳۳ یونیت (انگلیسی + پشتیبانیِ فارسی)، تلفظِ آفلاین (بریتیش/امریکن)، بانک سؤالِ شبیه‌آزمون با توضیحِ کاملِ هر گزینه، واژه‌نامهٔ ۷۳۸ اصطلاحی، و آزمون‌های زمان‌دار. ساختهٔ **EduPocket.org**.
