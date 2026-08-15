#!/usr/bin/env bash
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-$HOME/brain}"
git add -A
git diff --cached --quiet || git commit -qm "vault: $(date -Iseconds)"
# Rebase onto whatever the Mac pushed before pushing, or this fails non-fast-forward
# the first time a web clip lands and every later commit silently stays local.
git pull --rebase --autostash -q origin main || {
  git rebase --abort 2>/dev/null || true
  echo "pull/rebase failed — real conflict, resolve manually" >&2
  exit 0
}
git push -q origin main || echo "push failed, commit is local" >&2
