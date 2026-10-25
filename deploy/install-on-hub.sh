#!/bin/bash
# Runs on the hub VM, as your normal user (it sudoes where it must).
# Called by deploy/setup-from-desktop.sh; safe to re-run.
#   install-on-hub.sh app      service + tailscale serve on :10000 + backup key
#   install-on-hub.sh backup   first backup run + nightly timer
set -euo pipefail
D="$HOME/workout-tracker/deploy"
ME=$(id -un)

PORT=10000
OURS=http://127.0.0.1:8777

# What an HTTPS port on this machine is proxied to, or nothing.
proxy_for(){ sudo tailscale serve status --json 2>/dev/null | python3 -c '
import json, sys
try: web = json.load(sys.stdin).get("Web") or {}
except ValueError: web = {}
for host, cfg in web.items():
    if host.rsplit(":", 1)[-1] == sys.argv[1]:
        print(" ".join(h.get("Proxy", "?") for h in (cfg.get("Handlers") or {}).values()))
' "$1"; }

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

  # The hub VM serves three apps, one HTTPS port each (Tailscale allows only these three):
  #   443 → :3000 PPC Hub · 8443 → :3100 Shannon's sb-training · 10000 → :8777 this app
  echo "== tailscale serve, before:"; sudo tailscale serve status

  # An earlier version of this script took 8443 and hid Shannon's tracker. Hand it back.
  if [ "$(proxy_for 8443)" = "$OURS" ]; then
    echo "== :8443 points at this app — returning it to sb-training on :3100"
    sudo tailscale serve --bg --https=8443 http://127.0.0.1:3100 >/dev/null
  fi

  cur=$(proxy_for $PORT)
  if [ -n "$cur" ] && [ "$cur" != "$OURS" ]; then
    echo "!! :$PORT is already serving $cur — not taking it over. Nothing changed."; exit 1
  fi
  [ -z "$cur" ] && sudo tailscale serve --bg --https=$PORT $OURS >/dev/null

  echo "== after:"; st=$(sudo tailscale serve status); echo "$st"
  [ "$(proxy_for 443)" = "http://127.0.0.1:3000" ]  || echo "!! :443 isn't PPC Hub on :3000 — check https://ppc-hub.tail180281.ts.net"
  [ "$(proxy_for 8443)" = "http://127.0.0.1:3100" ] || echo "!! :8443 isn't sb-training on :3100 — check Shannon's link"
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
