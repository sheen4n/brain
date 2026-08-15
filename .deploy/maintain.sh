#!/usr/bin/env bash
# Nightly vault maintenance.
#
# Runs as root from systemd. Stops the interactive agent first so exactly one
# Claude process touches the vault — concurrent sessions race on git index.lock
# and can interleave edits to the same wiki page. Restarts it afterwards no
# matter what happens, via trap.
#
# Manual run:  sudo systemctl start brain-maintain
# Watch:       journalctl -u brain-maintain -f
set -uo pipefail

VAULT=/home/agent/brain
CLAUDE=/home/agent/.local/bin/claude
PROMPT_FILE="$VAULT/.deploy/maintenance-prompt.txt"
AGENT_PATH=/home/agent/.local/bin:/home/agent/.bun/bin:/usr/local/bin:/usr/bin:/bin
TIMEOUT=${MAINTAIN_TIMEOUT:-30m}

[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
[ -r "$PROMPT_FILE" ] || { echo "missing prompt file: $PROMPT_FILE" >&2; exit 1; }

was_active=no
systemctl is-active --quiet brain && was_active=yes

restore() {
  if [ "$was_active" = yes ]; then
    echo "--- restarting brain"
    systemctl start brain || echo "WARNING: failed to restart brain" >&2
  fi
}
trap restore EXIT

echo "--- stopping brain (was_active=$was_active)"
[ "$was_active" = yes ] && systemctl stop brain

echo "--- pulling remote changes"
sudo -u agent -H env HOME=/home/agent PATH="$AGENT_PATH" \
  git -C "$VAULT" pull --rebase --autostash -q origin main \
  || echo "WARNING: pull failed, continuing with local state" >&2

echo "--- running maintenance (timeout $TIMEOUT)"
set +e
timeout "$TIMEOUT" sudo -u agent -H env HOME=/home/agent PATH="$AGENT_PATH" \
  "$CLAUDE" -p "$(cat "$PROMPT_FILE")"
rc=$?
set -e

case "$rc" in
  0)   echo "--- maintenance ok" ;;
  124) echo "--- maintenance TIMED OUT after $TIMEOUT" >&2 ;;
  *)   echo "--- maintenance exited $rc" >&2 ;;
esac

# The Stop hook commits and pushes, but it does not run if claude was killed.
# Commit any stragglers so work is never left only on disk.
echo "--- sweeping uncommitted changes"
sudo -u agent -H env HOME=/home/agent PATH="$AGENT_PATH" \
  bash "$VAULT/.claude/hooks/commit.sh" || echo "WARNING: commit sweep failed" >&2

exit "$rc"
