#!/bin/bash
# Runs on the hub VM, as your normal user (it sudoes where it must).
# Called by deploy/setup-from-desktop.sh; safe to re-run.
#   install-on-hub.sh app      service + tailscale serve on :8443 + backup key
#   install-on-hub.sh backup   first backup run + nightly timer
set -euo pipefail
D="$HOME/workout-tracker/deploy"
ME=$(id -un)

unit(){ sed "s#/home/USER#$HOME#g; s/USER/$ME/g" "$D/$1" | sudo tee "/etc/systemd/system/$1" >/dev/null; }

case "${1:-}" in
app)
  [ -f "$HOME/workout-data/log.json" ] || echo "!! no ~/workout-data/log.json yet — the app will start from an empty log"
  unit workout-tracker.service
  sudo systemctl daemon-reload
  sudo systemctl enable --now workout-tracker
  sudo systemctl restart workout-tracker
  sleep 1
  n=$(curl -sf localhost:8777/api/log | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["entries"]))') \
    || { echo "!! server isn't answering — journalctl -u workout-tracker"; exit 1; }
  echo "== server up, $n entries"

  echo "== tailscale serve, before:"; sudo tailscale serve status
  sudo tailscale serve --bg --https=8443 http://127.0.0.1:8777 >/dev/null
  echo "== after:"; st=$(sudo tailscale serve status); echo "$st"
  echo "$st" | grep -q 3000  || echo "!! the hub's :3000 entry is missing — check https://ppc-hub.tail180281.ts.net"
  echo "$st" | grep -qi funnel && echo "!! funnel is on — this should be tailnet only"

  [ -f ~/.ssh/workout-data-deploy ] || ssh-keygen -q -t ed25519 -N "" -C "ppc-hub backup" -f ~/.ssh/workout-data-deploy
  ;;
backup)
  "$D/backup.sh"
  unit workout-backup.service
  unit workout-backup.timer
  sudo systemctl daemon-reload
  sudo systemctl enable --now workout-backup.timer
  systemctl list-timers workout-backup --no-pager
  ;;
*) echo "usage: $0 app|backup"; exit 2 ;;
esac
