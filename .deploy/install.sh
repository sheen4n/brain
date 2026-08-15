#!/usr/bin/env bash
# Install/refresh the brain systemd units. Run as root on the VPS:
#   sudo bash /home/agent/brain/.deploy/install.sh
# Idempotent — safe to re-run after editing any unit file.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo bash $0" >&2; exit 1; }

SRC="$(cd "$(dirname "$0")" && pwd)"
DST=/etc/systemd/system

UNITS=(
  brain.service
  brain-pull.service
  brain-pull.timer
  brain-maintain.service
  brain-maintain.timer
)

for u in "${UNITS[@]}"; do
  install -m 0644 "$SRC/$u" "$DST/$u"
  echo "installed $u"
done

chmod +x "$SRC/maintain.sh"

systemctl daemon-reload

# Timers can run now — harmless while an interactive session is up.
systemctl enable --now brain-pull.timer brain-maintain.timer

# brain-restart.timer is retired: brain-maintain stops and starts the agent as
# part of its run, which already gives the fresh session the blind nightly
# restart existed to provide. Leaving both enabled restarts twice a night.
if systemctl list-unit-files brain-restart.timer >/dev/null 2>&1; then
  systemctl disable --now brain-restart.timer 2>/dev/null || true
  rm -f "$DST/brain-restart.timer" "$DST/brain-restart.service"
  systemctl daemon-reload
  echo "retired brain-restart.timer (superseded by brain-maintain)"
fi

# brain.service is enabled but NOT started here: a second Claude Code instance
# polling the same bot token collides with any interactive `claude --channels`
# session (Telegram 409 Conflict). Stop the interactive session first, then:
#   systemctl start brain
systemctl enable brain.service

echo
echo "done. units installed, timers running."
echo
echo "  start agent:   systemctl start brain          (stop interactive session first)"
echo "  watch agent:   journalctl -u brain -f"
echo "  attach:        sudo -u agent tmux attach -t brain"
echo "  run maint now: systemctl start brain-maintain"
echo "  watch maint:   journalctl -u brain-maintain -f"
echo "  timers:        systemctl list-timers 'brain*'"
