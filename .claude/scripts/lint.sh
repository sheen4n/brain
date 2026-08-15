#!/usr/bin/env bash
# Vault lint: computes the link graph deterministically and reports its health.
# No database, no embeddings — just the filesystem. Safe to run any time; read-only
# except for the metrics line it appends to log.md.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-$HOME/brain}"

# Byte-order collation everywhere. sort and comm must agree on ordering or comm aborts
# with "input is not in sorted order"; under a UTF-8 locale they disagree as soon as a
# page basename or alias contains capitals or spaces (e.g. "OLLA", "Woodleigh Mall").
export LC_ALL=C

TMP=$(mktemp -d "${TMPDIR:-/tmp}/vaultlint.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# ------------------------------------------------------------------ name index
# "<page file>\t<name>" — every name a [[link]] may legally resolve to, i.e. the
# page's own basename plus each alias it declares in frontmatter.
find wiki -name '*.md' ! -name 'index.md' -print0 2>/dev/null \
| while IFS= read -r -d '' f; do
    printf '%s\t%s\n' "$f" "$(basename "$f" .md)"
    awk -v F="$f" '
      /^---[[:space:]]*$/ { if (++fence == 2) exit; next }
      fence == 1 && /^aliases:/ {
        sub(/^aliases:[[:space:]]*/, ""); gsub(/[][]/, ""); n = split($0, a, /,/)
        for (i = 1; i <= n; i++) {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[i])
          if (length(a[i])) print F "\t" a[i]
        }
      }' "$f"
  done | sort -u > "$TMP/names"

cut -f2 "$TMP/names" | sort -u > "$TMP/targets"
cut -f1 "$TMP/names" | sort -u > "$TMP/pages"

# ----------------------------------------------------------------------- edges
# "<source file>\t<link target>", one per line. Strips |display and #heading.
grep -roH '\[\[[^]]*\]\]' --include='*.md' wiki projects 2>/dev/null \
| awk -F':\\[\\[' '
    NF == 2 {
      sub(/\]\]$/, "", $2)
      split($2, a, /[|#]/)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[1])
      if (length(a[1])) print $1 "\t" a[1]
    }' \
| sort -u > "$TMP/edges" || true    # grep exits 1 when the vault has no [[links]] yet
[ -f "$TMP/edges" ] || : > "$TMP/edges"

cut -f2 "$TMP/edges" | sort | uniq -c | sort -rn > "$TMP/inbound"
cut -f2 "$TMP/edges" | sort -u > "$TMP/linked-names"

# A page counts as linked if its basename OR any of its aliases was linked to.
awk -F'\t' 'NR == FNR { L[$0]; next } ($2 in L) { print $1 }' \
  "$TMP/linked-names" "$TMP/names" | sort -u > "$TMP/linked-pages"

# System pages (type: system) are infrastructure — exempt from sourcing and orphan
# checks, but still valid link targets.
grep -rlE '^type:[[:space:]]*system' wiki --include='*.md' 2>/dev/null | sort -u > "$TMP/system" || true
[ -f "$TMP/system" ] || : > "$TMP/system"

# --------------------------------------------------------------------- reports
comm -23 "$TMP/linked-names" "$TMP/targets" > "$TMP/broken"
comm -23 "$TMP/pages" "$TMP/linked-pages" | comm -23 - "$TMP/system" > "$TMP/orphans"

# Pages that assert claims without citing a raw source.
find wiki -name '*.md' ! -name 'index.md' -print0 2>/dev/null \
| xargs -0 grep -L '^sources:' 2>/dev/null | sort | comm -23 - "$TMP/system" > "$TMP/unsourced" || true

# Raw sources no wiki page references yet — the ingest backlog.
: > "$TMP/backlog"
find raw -type f ! -name '.*' -print 2>/dev/null | sort | while IFS= read -r src; do
  grep -rqF "$src" wiki 2>/dev/null || echo "$src" >> "$TMP/backlog"
done

n_pages=$(find wiki -name '*.md' ! -name 'index.md' 2>/dev/null | wc -l | tr -d ' ')
n_edges=$(wc -l < "$TMP/edges" | tr -d ' ')
n_broken=$(wc -l < "$TMP/broken" | tr -d ' ')
n_orphans=$(wc -l < "$TMP/orphans" | tr -d ' ')
n_unsourced=$(wc -l < "$TMP/unsourced" | tr -d ' ')
n_backlog=$(wc -l < "$TMP/backlog" | tr -d ' ')

section() { [ -s "$2" ] && { printf '\n%s\n' "$1"; sed 's/^/  /' "$2"; } || true; }

echo "vault lint — $(date -Iseconds)"
echo "pages=$n_pages edges=$n_edges broken=$n_broken orphans=$n_orphans unsourced=$n_unsourced backlog=$n_backlog"

section "BROKEN LINKS (target does not exist — create the page or fix the link)" "$TMP/broken"
section "ORPHANS (no inbound links — link them from a hub or archive them)" "$TMP/orphans"
section "UNSOURCED (no sources: field — claims cannot be traced to raw/)" "$TMP/unsourced"
section "INGEST BACKLOG (raw sources not yet referenced by any wiki page)" "$TMP/backlog"

echo
echo "HUBS (highest inbound link count)"
head -10 "$TMP/inbound" | sed 's/^/  /'

# Append one machine-parseable line so health is trackable over time:
#   grep '| lint |' log.md
printf '## [%s] lint | pages=%s edges=%s broken=%s orphans=%s unsourced=%s backlog=%s\n' \
  "$(date +%F)" "$n_pages" "$n_edges" "$n_broken" "$n_orphans" "$n_unsourced" "$n_backlog" \
  >> log.md

[ "$n_broken" -eq 0 ] || exit 1
