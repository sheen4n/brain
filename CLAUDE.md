# LLM Wiki

A personal knowledge base on the Karpathy LLM-Wiki pattern. Plain Markdown, read directly.
No vector DB, no embeddings — find things by reading `wiki/index.md` and by grepping.

## Three layers

1. `raw/` — **immutable** source documents. Append only. NEVER edit or delete a file in `raw/`.
   Everything the wiki asserts must be traceable back here.
2. `wiki/` — pages you maintain, derived from `raw/`.
3. `log.md` — append-only record of every operation.

`projects/` sits outside the wiki: active work with an end state, not knowledge.

## Raw file contract

`raw/` has two producers — the `/capture` skill (Telegram) and Obsidian Web Clipper (browser).
Both write the same shape, so `/ingest` can rely on it:

    ---
    captured: YYYY-MM-DDTHH:MM:SSZ
    channel: telegram | web | file
    origin: <URL, or the Telegram message reference>
    author: <if known>
    published: <if known>
    ---

Filenames are `YYYY-MM-DD-<slug>.md` (Telegram adds `-HHMMSS`). Timestamped names are what
keep two machines writing to `raw/` from ever colliding — never reuse or rename one.

A raw file with missing frontmatter is still valid input. Ingest it and note the gap in the
source page rather than editing the raw file to fix it.

## Page types

**Entity** (`wiki/entities/`) — one page per distinct person, org, product, or place.
These are the hubs of the graph. When a source mentions an entity, either link its existing
page or create one. Never leave an entity as bare text.

**Concept** (`wiki/concepts/`) — topics and themes, synthesized across multiple sources.

**Source** (`wiki/sources/`) — one page per ingested raw document: metadata, 3-5 key
takeaways, links to every entity and concept it touched.

## Frontmatter

Every wiki page starts with:

    ---
    type: entity | concept | source
    title: Human readable title
    aliases: [other-name, nickname]
    created: YYYY-MM-DD
    updated: YYYY-MM-DD
    status: draft | active | archived
    sources: [raw/telegram/2026-08-13-...md]
    ---

- `aliases` is how entity resolution works. If a thing is called more than one name, list every
  name here. Without it the graph fragments into duplicate nodes.
- `sources` is mandatory on every page. A page with no `sources` is an unverifiable claim
  and lint will flag it.
- `status: draft` for anything generated without your review. Never silently promote to `active`.

## Linking

- `[[page-basename]]` — matches the filename without `.md`, or any declared alias.
- `[[page|display text]]` and `[[page#heading]]` both work.
- Link aggressively. The value of this vault is link density, not page count. If a page
  mentions something that has or should have its own page, link it.
- Every claim cites the source page or the raw path it came from.
- Never delete a page. Set `status: archived` so inbound links keep resolving.
- Filenames: kebab-case, descriptive. No dates except on source pages, which use `YYYY-MM-DD-slug`.

## Indexes

`wiki/index.md` is the top-level router and every subfolder has its own `index.md`.
Regenerate the affected indexes on every ingest. A single flat index stops routing at
roughly 200 pages, which is why the per-folder ones exist.

## Fan-out expectation

A single non-trivial source normally touches **10–15 pages**: one source page, several entity
pages updated, one or two concept pages, plus the indexes. Writing one note and stopping means
the ingest was not done.

## Workflows

Use the skills, do not improvise: `/capture`, `/ingest`, `/find`, `/lint`.

## Human role

You curate sources and ask questions. I do the bookkeeping, synthesis, and maintenance.
I propose new pages; I do not silently accept my own answers as fact — they land as
`status: draft` for you to promote.
