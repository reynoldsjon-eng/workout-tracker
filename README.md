# Training

A workout logger built around a Huberman-adapted 6–7 day strength + endurance plan.
Single self-contained `index.html` — no build step, no dependencies.

Served at `https://reynoldsjon-eng.github.io/workout-tracker/`.

## What's here

| File | |
|---|---|
| `index.html` | The whole app — markup, styles, logic |
| `sw.js` | Service worker, offline shell |
| `manifest.json` | PWA metadata for Add to Home Screen |
| `icon-*.png` | Home screen icons |

## Stats

A fourth tab, over a 6-week / 6-month / all-time window:

- **Consistency** — a day-per-cell grid of lifts, rides and mobility ticks. Tap a
  day to open that session.
- **Progression** — per-exercise estimated 1RM (Epley), so a 4×5 in Block A and a
  4×12 in Block B sit on one axis. Bodyweight lifts chart total reps instead.
- **PRs** — a set that beats your best e1RM for that lift is flagged as you log it,
  and stays badged in history.
- **Weekly sets** — sets per week, broken out by muscle group. Tap a group to
  filter the chart to it.
- **Personal bests** — heaviest estimated 1RM per lift.

Everything is derived from the existing entry log, so importing old history
backfills it. Per-week rates divide by the weeks you were actually training,
not by the width of the window. Charts cap at 26 weeks; the tiles don't.

## Install on iPhone

Open the URL in **Safari** (not Chrome — only Safari can install to the Home Screen),
then Share → **Add to Home Screen**. It launches full-screen with no browser chrome
and works offline.

## Storage

Logs live in IndexedDB on the device, as an append-only list of entries — one per
set, ride or mobility tick, each with its own id and timestamp. Edits supersede by
id; deletes are tombstones. That makes merging across devices lossless once sync
lands.

Falls back to `localStorage`, then to memory, if IndexedDB is unavailable — with a
visible warning rather than a blank screen.

**No personal training data belongs in this repo.** It's public so GitHub Pages can
serve it. Logs sync to a separate private repo.

## Local development

```
python -m http.server 8777 --directory app
```

Opening `index.html` straight off disk works on desktop, but there is no service
worker and no Home Screen install — and on iOS the Files app preview won't run it
at all.
