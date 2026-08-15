#!/usr/bin/env bash
# Install/refresh the brain systemd units. Run as root on the VPS:
#   sudo bash ~/brain/.deploy/install.sh
# Idempotent — safe to re-run after editing any unit file.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo bash $0" >&2; exit 1; }

SRC="$(cd "$(dirname "$0")" && pwd)"
DST=/etc/systemd/system

for u in brain.service brain-restart.service brain-restart.timer brain-pull.service brain-pull.timer; do
  install -m 0644 "$SRC/$u" "$DST/$u"
  echo "installed $u"
done

systemctl daemon-reload

# Timers can start now (harmless while the interactive session runs).
systemctl enable --now brain-restart.timer brain-pull.timer

# brain.service is enabled but NOT started here: a second Claude Code instance
# polling the same bot token collides with any interactive `claude --channels`
# session (Telegram 409 Conflict). Stop the interactive session first, then:
#   systemctl start brain
systemctl enable brain.service

echo
echo "done. units installed and timers running."
echo "next: stop any interactive 'claude --channels' session, then: systemctl start brain"
echo "watch:  journalctl -u brain -f     attach: sudo -u agent tmux attach -t brain"
