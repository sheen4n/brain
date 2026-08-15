---
name: find
description: Answer a question from the vault, with citations. Use for any recall question about stored knowledge.
---

1. **Route** — read `wiki/index.md`, then the relevant subfolder `index.md`.
2. **Grep** — search for the terms and their likely aliases across `wiki/`. Then grep `raw/`
   too: the answer may be captured but not yet ingested.
3. **Traverse** — follow `[[links]]` out of the pages you hit. Check backlinks with
   `grep -rl '\[\[<page>\]\]' wiki/`. Two hops is usually enough.
4. **Answer** with citations — name the pages, and the raw sources behind them.
5. **State gaps honestly.** If the vault does not contain the answer, say so rather than
   filling from general knowledge. If you do use outside knowledge, mark it as such.
6. **Compound** — if the answer is durable and reusable, propose a new concept page as
   `status: draft`. Do not auto-accept it as fact.
