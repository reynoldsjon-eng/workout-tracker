#!/bin/bash
# One-shot setup of the training app on the hub, run from the desktop in Git Bash:
#
#   curl -fsSLO https://raw.githubusercontent.com/reynoldsjon-eng/workout-tracker/main/deploy/setup-from-desktop.sh && bash setup-from-desktop.sh
#
# Needs `ssh hub` working and a GitHub login that can read workout-data.
# Safe to re-run: every step checks before it acts.
set -euo pipefail
HUB=${HUB:-hub}
say(){ printf '\n\033[1m== %s\033[0m\n' "$*"; }

say "1/3  Copy the log to the hub"
if ssh "$HUB" 'test -f ~/workout-data/log.json'; then
  echo "already there — leaving it alone"
else
  tmp=$(mktemp -d)
  git clone -q --depth 1 https://github.com/reynoldsjon-eng/workout-data.git "$tmp/wd"
  ssh "$HUB" 'mkdir -p ~/workout-data'
  scp -q "$tmp/wd/log.json" "$HUB:workout-data/log.json"
  rm -rf "$tmp"
  echo "copied"
fi

say "2/3  App service + tailscale serve on :10000"
ssh "$HUB" 'if [ -d ~/workout-tracker/.git ]; then git -C ~/workout-tracker pull -q --ff-only;
            else git clone -q https://github.com/reynoldsjon-eng/workout-tracker.git ~/workout-tracker; fi'
ssh -t "$HUB" 'bash ~/workout-tracker/deploy/install-on-hub.sh app'

say "3/3  Nightly backup"
pub=$(ssh "$HUB" 'cat ~/.ssh/workout-data-deploy.pub')
if command -v gh >/dev/null && gh repo deploy-key list -R reynoldsjon-eng/workout-data 2>/dev/null | grep -q ppc-hub; then
  echo "deploy key already on GitHub"
elif command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  printf '%s\n' "$pub" > /tmp/ppc-hub-backup.pub
  gh repo deploy-key add /tmp/ppc-hub-backup.pub --allow-write -t "ppc-hub backup" -R reynoldsjon-eng/workout-data
  rm -f /tmp/ppc-hub-backup.pub
else
  echo "Add this as a deploy key on workout-data, with 'Allow write access' ticked:"
  echo "  https://github.com/reynoldsjon-eng/workout-data/settings/keys/new"
  echo
  echo "$pub"
  echo
  read -rp "Press Enter once it's added… "
fi
ssh -t "$HUB" 'bash ~/workout-tracker/deploy/install-on-hub.sh backup'

say "Done — open https://ppc-hub.tail180281.ts.net:10000/ on the phone"
