---
type: concept
title: Deploy key scoping
aliases: [vault-deploy-key]
created: 2026-08-15
updated: 2026-08-15
status: draft
sources: [raw/telegram/2026-08-15-081719-brain-box-hel1-deploy-key.md]
---

# Deploy key scoping

How much a machine's git credential is allowed to reach — one repository, or everything the
account can touch.

## In this vault

- The [[brain-box]] key is **vault-only**: it grants access to the vault repository and
  nothing else (`raw/telegram/2026-08-15-081719-brain-box-hel1-deploy-key.md`, filed as
  [[2026-08-15-brain-box-hel1-deploy-key]]).
- Practical consequence recorded here so it is not rediscovered later: any operation on the
  [[brain-box]] that needs a *different* repository will fail on auth, and needs its own
  credential rather than a widening of this one.

## Gaps

- Whether the key is read-only or read-write is not stated in any source on disk.
