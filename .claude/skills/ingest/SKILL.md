---
name: ingest
description: Turn one or more raw/ sources into wiki pages — source summary, entity and concept updates, indexes, log. Use when processing the backlog or when a captured item is worth filing now.
---

The heavy workflow. Per the schema, a non-trivial source touches 10-15 pages.

1. **Read** the raw source in full.
2. **Extract** every distinct entity (person, org, product, place) and every concept.
3. **Source page** — create `wiki/sources/YYYY-MM-DD-<slug>.md`: metadata, 3-5 key takeaways,
   `[[links]]` to every entity and concept it touches.
4. **Entity pages** — for each entity, update the existing page or create one.
   Before creating, grep for the name AND likely aliases; if a page exists under another
   name, add the alias to that page instead of creating a duplicate.
5. **Concept pages** — update or create, synthesizing across sources rather than restating one.
6. **Cite everything.** Each claim names the source page or raw path it came from.
7. **Indexes** — regenerate `wiki/index.md` and each affected subfolder `index.md`.
8. **Contradictions** — where a new source disagrees with an existing page, do NOT silently
   overwrite. Add an entry to `wiki/open-questions.md` linking both pages, and flag the
   disputed claim inline.
9. **Log** — append `## [YYYY-MM-DD] ingest | <source> | pages touched: N`.
10. Everything you author lands `status: draft`. Only the human promotes to `active`.

Finish by running `/lint` and fixing anything you just broke.
