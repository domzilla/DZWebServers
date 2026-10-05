---
id: '261005-1NRTB5E'
title: URL-encoded form parser mishandles leading & and empty keys
author: Dominic Rodemer
created_at: '2026-10-05T15:17:46.368422Z'
status: open
labels:
- bug
---

> **Note:** Produced during an autonomous agent run (test-suite review, 2026-10-05) and not verified by a human. This may be totally wrong — analyze and confirm before fixing.

## Problem

`DZWebServerParseURLEncodedForm` (`DZWebServerFunctions.m:206-240`):

- `"&a=1&b=2"` → `{"&a": "1", …}`: a leading `&` isn't skipped.
- `"=v&a=1"` → `{}`: the loop breaks on the empty key, so every later pair is lost.

## Test

Known-issue test in `src/DZWebServersTests/`.
