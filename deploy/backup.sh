#!/bin/sh
# Nightly off-box copy: commits ~/workout-data/log.json to the private
# workout-data repo, so the log survives the hub's NVMe.
#
# Pushes with a deploy key that can write to that one repo and nothing else
# (README → Self-hosting → Off-box backup). Run by workout-backup.timer;
# safe to run by hand.
set -eu

LOG="$HOME/workout-data/log.json"
REPO="$HOME/workout-data-backup"
KEY="$HOME/.ssh/workout-data-deploy"
REMOTE="${WT_BACKUP_REMOTE:-git@github.com:reynoldsjon-eng/workout-data.git}"
export GIT_SSH_COMMAND="ssh -i $KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

count() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(len(d if isinstance(d, list) else d["entries"]))' "$1"; }

[ -f "$LOG" ] || { echo "no log at $LOG"; exit 1; }
new=$(count "$LOG") || { echo "$LOG isn't valid JSON — not backing it up"; exit 1; }

[ -d "$REPO/.git" ] || git clone -q "$REMOTE" "$REPO"
cd "$REPO"
git fetch -q origin
git reset -q --hard origin/HEAD          # the repo is a mirror; history keeps anything it held

# The log is append-only (deletes are tombstones), so it never shrinks.
# If it has, something went wrong on the hub — keep the last good copy.
if [ -f log.json ]; then
  old=$(count log.json)
  if [ "$new" -lt "$old" ]; then
    echo "log shrank from $old to $new entries — not overwriting the backup"; exit 1
  fi
fi

cp "$LOG" log.json
git add log.json
if git diff --cached --quiet; then echo "unchanged ($new entries)"; exit 0; fi
git -c user.name="ppc-hub backup" -c user.email="backup@ppc-hub" commit -qm "backup: $new entries"
git push -q origin HEAD
echo "pushed $new entries"
