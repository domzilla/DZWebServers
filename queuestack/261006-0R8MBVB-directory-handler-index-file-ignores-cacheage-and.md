---
id: '261006-0R8MBVB'
title: Directory handler index file ignores cacheAge and range requests
author: Dominic Rodemer
created_at: '2026-10-06T06:54:12.278648Z'
status: open
labels:
- bug
---

> **Note:** Agent-generated from an automated doc/code review. This may be a false positive — analyze and confirm against the code before fixing.

## Parent

261006-0RVAHY0

`DZWebServer.m:1060-1065` returns the index file response directly via `return [DZWebServerFileResponse responseWithFile:indexPath]`, skipping `cacheControlMaxAge = cacheAge` (line 1078) and the `allowRangeRequests` byte-range path.
Impact: index.html served with no cache headers and Range requests ignored, unlike other files.
Fix: assign to `response` and reuse the regular-file branch logic instead of early return.
