---
id: '261005-1NRTAKP'
title: WebDAV COPY onto existing destination returns 403
author: Dominic Rodemer
created_at: '2026-10-05T15:17:46.308096Z'
status: open
labels:
- bug
---

> **Note:** Produced during an autonomous agent run (test-suite review, 2026-10-05) and not verified by a human. This may be totally wrong — analyze and confirm before fixing.

## Problem

`DZWebDAVServer.m:394`: COPY with `Overwrite: T` (or no Overwrite header) onto an existing destination fails with 403 "Failed copying". MOVE removes the destination first; COPY doesn't.

- Expected: 204 No Content (RFC 4918 §9.8.5)
- Actual: 403

## Test

Known-issue test in `src/DZWebServersTests/`.
