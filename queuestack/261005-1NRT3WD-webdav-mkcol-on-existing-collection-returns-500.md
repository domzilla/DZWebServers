---
id: '261005-1NRT3WD'
title: WebDAV MKCOL on existing collection returns 500
author: Dominic Rodemer
created_at: '2026-10-05T15:17:46.338124Z'
status: open
labels:
- bug
---

> **Note:** Produced during an autonomous agent run (test-suite review, 2026-10-05) and not verified by a human. This may be totally wrong — analyze and confirm before fixing.

## Problem

`DZWebDAVServer.m:310`: MKCOL on a collection that already exists returns 500.

- Expected: 405 Method Not Allowed (RFC 4918 §9.3.1)
- Actual: 500

## Test

Known-issue test in `src/DZWebServersTests/`.
