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

## Earlier days

Sessions don't have to be logged the day they happen.

- **Today → Log or edit an earlier day**, **History → + Earlier day**, or a tap on any
  empty square in the Stats heatmap opens a day picker — the last fortnight at a
  glance, plus a date field for anything older.
- Picking a day lists what's already logged there and what you can add. Both land on
  the normal session screen, dated to that day, with an amber **Logging to…** banner
  so a backfill is never mistaken for a live session. The rest timer stays out of it.
- Opening a session that's already logged brings its sets back ticked and editable.
  Retype a weight or reps and it saves on blur, to the same entry — no duplicates.
  Untick a set to drop it.
- **History → a session → Edit session** is the same screen, and **Delete** removes a
  session outright.

Weight suggestions and the "Last …" line come from the session before the day you're
editing, not from the newest one, so backfilling last week doesn't quote next week
back at you. The block is taken from what the sets were logged under.

Nothing here is destructive: edits reuse the entry's id and deletes write tombstones,
so an edit made on the phone still merges cleanly with a laptop that never saw it.

## Equipment

The rack and the machines get set the same way every week, and re-finding the right
hole mid-warm-up is its own small tax. **Settings → Equipment settings** keeps a
label/value pair per exercise — *J-clips → just under hole 17* — and the same
settings show as chips on the exercise card while you're logging it, which is where
you actually need them.

- A setting is keyed on exercise + label, so saving the same label twice corrects it
  rather than stacking a duplicate. Renaming a label moves the entry and retires the
  old one.
- They're `gear` entries in the same append-only log, so they sync, merge and export
  with everything else. They carry no date — this is config, not history — so they
  stay out of sessions, stats and the heatmap.
- The two bench-press settings in `GEAR_SEED` are the starting set, written once on
  a device that has no equipment entries at all (tombstones included, so a device
  that has already synced never gets them written back over its own). Everything
  after is added in the app and lives only in the private log.

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
