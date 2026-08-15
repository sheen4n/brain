---
name: lint
description: Run the vault health check and repair what it finds. Use on a schedule and after any large ingest.
---

1. Run `.claude/scripts/lint.sh` and read the report.
2. Work the findings in this order:
   - **Broken links** — create the missing page, or fix the link if it was a typo.
     Prefer creating: a broken link usually means a real entity nobody wrote up yet.
   - **Unsourced pages** — trace the claims to a raw source and add `sources:`.
     If nothing in `raw/` supports the page, mark it `status: draft` and note it in
     `wiki/open-questions.md`.
   - **Orphans** — link from the relevant hub or index. If genuinely obsolete, set
     `status: archived`. Never delete.
   - **Backlog** — run `/ingest` on the un-ingested raw sources.
3. Re-run the script and confirm `broken=0`.
4. Report the before/after metrics line. Do not narrate every individual fix.

Health over time: `grep '| lint |' log.md`. Broken and unsourced should trend to zero;
pages and edges should grow together — edges growing slower than pages means the graph
is fragmenting.
