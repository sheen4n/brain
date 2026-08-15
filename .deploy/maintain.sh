#!/usr/bin/env bash
# Nightly vault maintenance.
#
# Runs as root from systemd. Stops the interactive agent first so exactly one
# Claude process touches the vault — concurrent sessions race on git index.lock
# and can interleave edits to the same wiki page. Restarts it afterwards no
# matter what happens, via trap.
#
# Manual run:  systemctl start --no-block brain-maintain
# Watch:       journalctl -u brain-maintain -f
set -uo pipefail

VAULT=/home/agent/brain
CLAUDE=/home/agent/.local/bin/claude
PROMPT_FILE="$VAULT/.deploy/maintenance-prompt.txt"
AGENT_PATH=/home/agent/.local/bin:/home/agent/.bun/bin:/usr/local/bin:/usr/bin:/bin
TIMEOUT=${MAINTAIN_TIMEOUT:-30m}

[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
[ -r "$PROMPT_FILE" ] || { echo "missing prompt file: $PROMPT_FILE" >&2; exit 1; }

# CRITICAL: Claude resolves its project directory from the working directory.
# Without this, it launches in / and never loads $VAULT/.claude/settings.json,
# so every Write/Edit/Bash is denied — and `claude -p` still exits 0, making the
# whole run a silent no-op. Skills still load (directory-scoped), so the run
# looks healthy right up until the first write.
cd "$VAULT" || { echo "cannot cd to $VAULT" >&2; exit 1; }

as_agent() {
  sudo -u agent -H env HOME=/home/agent PATH="$AGENT_PATH" "$@"
}

# Prints the lint metrics line, and appends one to log.md as a side effect.
lint_metrics() {
  as_agent bash "$VAULT/.claude/scripts/lint.sh" 2>/dev/null | grep -m1 '^pages=' || true
}

backlog_of() { printf '%s' "${1:-}" | sed -n 's/.*backlog=\([0-9]*\).*/\1/p'; }

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
as_agent git -C "$VAULT" pull --rebase --autostash -q origin main \
  || echo "WARNING: pull failed, continuing with local state" >&2

before=$(lint_metrics)
echo "--- lint before: ${before:-<lint failed>}"

echo "--- running maintenance (cwd=$PWD, timeout $TIMEOUT)"
timeout "$TIMEOUT" as_agent "$CLAUDE" -p "$(cat "$PROMPT_FILE")"
rc=$?

case "$rc" in
  0)   echo "--- claude exited 0" ;;
  124) echo "--- claude TIMED OUT after $TIMEOUT" >&2 ;;
  *)   echo "--- claude exited $rc" >&2 ;;
esac

# The Stop hook does not run if claude was killed. Sweep so finished work is
# never left only on disk.
echo "--- sweeping uncommitted changes"
as_agent bash "$VAULT/.claude/hooks/commit.sh" || echo "WARNING: commit sweep failed" >&2

after=$(lint_metrics)
echo "--- lint after:  ${after:-<lint failed>}"

# Exit 0 from claude does NOT mean work happened — a permissions or cwd problem
# produces a clean exit and an untouched vault. Compare the backlog instead.
b0=$(backlog_of "$before"); b1=$(backlog_of "$after")
if [ -n "$b0" ] && [ -n "$b1" ] && [ "$b0" -gt 0 ] && [ "$b1" -ge "$b0" ]; then
  echo "WARNING: backlog did not shrink ($b0 -> $b1) — maintenance did nothing." >&2
  echo "WARNING: check permissions and that cwd is the vault." >&2
  exit 1
fi

echo "--- maintenance ok"
exit "$rc"
