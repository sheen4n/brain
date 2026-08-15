---
name: capture
description: Save an incoming message or link to raw/ immediately, with no synthesis. Use for every inbound Telegram message that contains information worth keeping.
---

Fast path. Do NOT synthesize, summarize, or file into the wiki — that is `/ingest`.

1. Write the raw text verbatim to `raw/telegram/YYYY-MM-DD-HHMMSS-<slug>.md`.
   Use the real current date and time. Slug is 3-5 kebab-case words from the content.
2. Prepend frontmatter: `captured:` timestamp, `channel: telegram`, `origin:` (URL if the
   message was a link).
3. If it was a URL, fetch the page and save the readable text to `raw/web/` alongside it.
4. Append to `log.md`: `## [YYYY-MM-DD] capture | <slug>`
5. Reply with one line confirming what was saved and where.

Never lose the original wording. Capture is lossless; restructuring happens later.
