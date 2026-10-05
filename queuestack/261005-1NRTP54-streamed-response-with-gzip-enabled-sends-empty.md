---
id: '261005-1NRTP54'
title: Streamed response with gzip enabled sends empty body
author: Dominic Rodemer
created_at: '2026-10-05T15:17:46.353670Z'
status: open
labels:
- bug
---

> **Note:** Produced during an autonomous agent run (test-suite review, 2026-10-05) and not verified by a human. This may be totally wrong — analyze and confirm before fixing.

## Problem

`DZWebServerResponse.m:61-63`: with `isGZipContentEncodingEnabled = YES`, a `DZWebServerStreamedResponse` sends an empty body. The gzip encoder only forwards the synchronous `readData:`, but the streamed response only implements `asyncReadDataWithCompletion:`.

## Test

Known-issue test in `src/DZWebServersTests/`.
