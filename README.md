# Training

A workout logger built around a Huberman-adapted 6–7 day strength + endurance plan.
Single self-contained `index.html` — no build step, no dependencies.

Self-hosted on the house mini PC at `https://ppc-hub.tail180281.ts.net:10000/` (see **Self-hosting**). The GitHub Pages copy at
`https://reynoldsjon-eng.github.io/workout-tracker/` still works with GitHub sync.

## What's here

| File | |
|---|---|
| `index.html` | The whole app — markup, styles, logic |
| `sw.js` | Service worker, offline shell |
| `manifest.json` | PWA metadata for Add to Home Screen |
| `server.py` | Self-hosted server: serves the app and keeps `log.json` |
| `deploy/workout-tracker.service` | systemd unit for `server.py` |
| `deploy/backup.sh`, `workout-backup.*` | nightly push of `log.json` to the private repo |
| `deploy/setup-from-desktop.sh`, `install-on-hub.sh` | one-command install on the hub |
| `icon-*.png` | Home screen icons |

## Blocks

**Settings → Training block** switches between A and B.

- **Block A** is strength: the original exercise list at 4×4–6 on mains.
- **Block B** is hypertrophy, and swaps in its own lifting-day exercises:
  - **Legs:** back squat (Block A is front squat) and cable leg extensions.
  - **Upper:** incline barbell bench and chin-ups.
  - **Arms:** weighted single-leg calf raises.
  
  Reps run 8–15. Cardio days are unchanged.

Each B exercise has its own id, so progression and PRs don't mix the two lists.
Sessions keep the block they were logged under.

The current block and its start date are stored in the synced log (a `setting`
entry), so every device and every fresh install agrees on them. Settings has a
**Started** date to correct the week count.

An open session can be switched with **Switch to A/B** in its header. Ticked sets
stay and are re-tagged to the new block. Sets for exercises the new block doesn't
have stay on as one-offs. Unticked rows are rebuilt from the new block's list.
Switching today's session also makes that the current block.

## Suggested progression

An open lift shows 2–4 options worked out from the last session at that lift:
**Add reps**, **Add weight**, **Repeat**, and **Reset −10%** when Stats flags it
as plateaued or slipping. One is starred as the recommendation. Tapping one fills
in the sets you haven't ticked yet.

It uses double progression:
- Add reps until every working set reaches the top of the range, then add
  weight and drop back to the bottom.
- Repeat if the last session fell short of the range or was logged at RPE 9.5+.
- Warm-up ramp sets below the top weight are left alone.
- Every suggested load is one the kit can actually make (see Equipment).

## Equipment

Suggested loads and the ± weight buttons under the active set only land on
loads the home gym can make:

| Kit | Steps |
|---|---|
| TRULAP 92 lb adjustable dumbbells | 8.5, 12, 15.5 … 88.5, 92 (3 / 3.5 lb). A logged 42.5 reads as the 42 setting. |
| Cable stack | 10 lb |
| Barbell (2.5 / 5 / 10 lb change plates) | +5 lb (2.5 a side); +10 on squats, deadlifts and hip thrusts |
| Landmine, added weight on pull-ups/chin-ups | 5 lb |

Equipment is inferred from the exercise name, with overrides in `EQUIP` for
names that would be misread (e.g. Romanian Deadlift is done with dumbbells).

## Metcons

On the HIIT day, the Today card offers four metcons to swap in for the Zwift
session. Each has 12–18 min of hard work and takes ~30 min with warm-up:
**Tabata Triple**, **EMOM 16**, **90/90 Intervals** and the **12-min Burner**.
They log like a ride, with a duration, a free-text score, HR and RPE.

The bike is warm-up only. Clipless pedals mean a shoe change, so the work blocks
use burpees, wall balls, dumbbells and the box, and cool-downs are on foot.

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

## Stats

A fourth tab, over a 6-week / 6-month / all-time window:

- **Consistency** — a day-per-cell grid of lifts, rides and mobility ticks. Tap a
  day to open that session.
- **Progression** — per-exercise estimated 1RM (Epley), so a 4×5 in Block A and a
  4×12 in Block B sit on one axis. Bodyweight lifts chart total reps instead.
- **PRs** — a set that beats your best e1RM for that lift is flagged as you log it,
  and stays badged in history.
- **Plateau watch** — every lift trained in the window, with a sparkline and a
  status, stalls first. **Plateau** means no new best for 3+ sessions over 3+
  weeks. **Holding** means 2 sessions without one. **Slipping** means both of
  the last two sessions came in 5%+ under the best. Tap a lift to chart it.
  Matching a best doesn't count as beating it.
- The **Progression** chart switches between e1RM, top weight and volume. A
  dashed best-so-far line and a shaded stretch show how long it's been flat.
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
serve it. Logs sync to `log.json` on the self-hosted server, kept outside this
checkout, or to a separate private repo.

Sync has two backends behind the same pull → merge → push loop:
- **Server** — when the page is served by `server.py`, it syncs to that server with no
  setup. The server rejects a write made against a stale copy (409), and the app
  refetches and merges, as with GitHub.
- **GitHub** — a private repo and a fine-grained token, set up under Settings → Sync.

## Self-hosting

`server.py` serves the app and `log.json` from one origin. It uses only the Python
standard library. It binds to localhost, and `tailscale serve` puts HTTPS in front of it.
Safari needs HTTPS for the offline service worker and Add to Home Screen. Anyone on
the tailnet can read and write the log, and nobody outside it can reach it.

It runs in the **hub VM** on the house mini PC (Proxmox). That VM already runs the
Pinot Pony Club Hub (`next start` on :3000) and is on the tailnet as `ppc-hub`. The
VM serves three apps, one HTTPS port each. Tailscale only allows HTTPS on these three
ports, so all of them are now taken:

| Port | App | Local |
|---|---|---|
| 443 | PPC Hub | `:3000` |
| 8443 | Shannon's tracker (`sb-training`) | `:3100` |
| **10000** | **this app** | `:8777` |

Each port is its own origin, so the apps' storage and service workers stay separate.
The installer won't take a port that's already serving something else.

Unlike the hub, which is copied over from the Windows desktop, this app deploys with
`git pull` on the VM. The repo is public, and git leaves CRLF, directory permissions
and machine-local files alone, which are the traps in the hub's `HUB_HOST.md`. The log
lives in `~/workout-data/`, outside the checkout, so no deploy can overwrite it.

**The quick way:** from the desktop, in Git Bash, run

```
curl -fsSLO https://raw.githubusercontent.com/reynoldsjon-eng/workout-tracker/main/deploy/setup-from-desktop.sh && bash setup-from-desktop.sh
```

It does everything below: it copies the log, installs the service, sets up
`tailscale serve` on :10000 and checks the hub's and Shannon's entries are intact, then sets up the
backup. It adds the deploy key itself if `gh` is logged in. Otherwise it prints the
key and waits while you add it. It asks for the hub's sudo password, and it's safe
to re-run. The manual steps follow.

Once, from the desktop in Git Bash, copy the existing log over from the private repo
(the hub VM has no GitHub login, so it can't clone it). The alternative is Export /
Import, below.

```
git clone https://github.com/reynoldsjon-eng/workout-data.git /tmp/wd
ssh hub 'mkdir -p ~/workout-data' && scp /tmp/wd/log.json hub:workout-data/ && rm -rf /tmp/wd
```

Then in the hub VM (`ssh hub`):

```
git clone https://github.com/reynoldsjon-eng/workout-tracker.git ~/workout-tracker

# A system service, like ppc-hub.service
sed "s/USER/$USER/g" ~/workout-tracker/deploy/workout-tracker.service \
  | sudo tee /etc/systemd/system/workout-tracker.service >/dev/null
sudo systemctl daemon-reload && sudo systemctl enable --now workout-tracker
curl -s localhost:8777/api/log | head -c 200   # should show your entries

# HTTPS on the tailnet: https://ppc-hub.tail180281.ts.net:10000/
tailscale serve status                       # note the hub's existing 443 entry
sudo tailscale serve --bg --https=10000 http://127.0.0.1:8777
tailscale serve status                       # 443 → :3000 and 8443 → :3100 untouched, 10000 → :8777 added
```

Don't run a bare `tailscale serve --bg 8777`, which maps port 443 and replaces the hub.
Don't use 8443 either: that's Shannon's.
Use `serve`, never `funnel`.

```
systemctl status workout-tracker
journalctl -u workout-tracker -f
```

**Deploying** from the desktop, after a change is merged to `main`:

```
ssh hub 'cd ~/workout-tracker && git pull --ff-only && sudo systemctl restart workout-tracker'
```

The restart only matters when `server.py` changed. App changes reach the phone on
its next online launch.

**Moving a phone over.** Each URL is its own origin with its own storage, so the new
one starts empty and fills from the server on first launch.
1. On the old app, Settings → **Sync now**. If you didn't copy `log.json` from the
   private repo, use **Export log.json** here too.
2. Open `https://ppc-hub.tail180281.ts.net:10000/` in Safari. It connects to the server on its own. If you
   exported, use **Import log.json**.
3. Share → **Add to Home Screen**, and delete the old icon.

**Backups.** Writes are atomic, and the first write each day copies the previous
`log.json` to `~/workout-data/backups/log-YYYY-MM-DD.json`. Those copies are on the
same NVMe that `HUB_HOST.md` says to watch, and Proxmox backups aren't configured yet.
So `deploy/backup.sh` commits the log to the private `workout-data` repo each night
at 03:17. It skips the commit if nothing changed. It refuses to overwrite the backup
if the log has fewer entries than last time, because an append-only log never
shrinks. Every night's version is kept in that repo's git history.

**Off-box backup setup**, once, in the hub VM:

```
ssh-keygen -t ed25519 -N "" -C "ppc-hub backup" -f ~/.ssh/workout-data-deploy
cat ~/.ssh/workout-data-deploy.pub
```

Add that public key on GitHub: `workout-data` → Settings → Deploy keys → Add deploy
key, with **Allow write access** ticked. The key can only reach that one repo. Then:

```
~/workout-tracker/deploy/backup.sh            # first run: clones, commits, pushes
for f in workout-backup.service workout-backup.timer; do
  sed "s/USER/$USER/g" ~/workout-tracker/deploy/$f | sudo tee /etc/systemd/system/$f >/dev/null
done
sudo systemctl daemon-reload && sudo systemctl enable --now workout-backup.timer
systemctl list-timers workout-backup          # next run
journalctl -u workout-backup                  # what the last run did
```

Restoring is copying `log.json` from `workout-data` back to `~/workout-data/`. Or
import it in the app, which merges instead of replacing.

A phone still on GitHub sync merges whatever the backup pushes, so leaving an old
install connected loses nothing.

## Local development

```
python3 server.py --data ./data/log.json
```

`data/` is gitignored.

Opening `index.html` straight off disk works on desktop, but there is no service
worker and no Home Screen install — and on iOS the Files app preview won't run it
at all.
