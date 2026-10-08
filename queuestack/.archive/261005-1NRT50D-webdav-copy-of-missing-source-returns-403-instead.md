---
id: '261005-1NRT50D'
title: WebDAV COPY of missing source returns 403 instead of 404
author: Dominic Rodemer
created_at: '2026-10-05T15:17:46.323535Z'
status: closed
labels:
- bug
---


> **Note:** Produced during an autonomous agent run (test-suite review, 2026-10-05) and not verified by a human. This may be totally wrong — analyze and confirm before fixing.

## Parent

261006-0RVAHY0

## Problem

`DZWebDAVServer.m` `performCOPY` never checks that the source exists, so the copy fails and returns 403.

- Expected: 404 Not Found
- Actual: 403

## Test

Known-issue test in `src/DZWebServersTests/`.

## Blocked by

- 261005-1NRTPZ2 — WebDAV COPY/MOVE ignore allowedFileExtensions
