---
id: '261005-1NRTPZ2'
title: WebDAV COPY/MOVE ignore allowedFileExtensions
author: Dominic Rodemer
created_at: '2026-10-05T15:17:46.291524Z'
status: open
labels:
- bug
---

> **Note:** Produced during an autonomous agent run (test-suite review, 2026-10-05) and not verified by a human. This may be totally wrong — analyze and confirm before fixing.

## Problem

In `DZWebDAVServer.m:356-367` (COPY/MOVE), `isDirectory` is overwritten by the destination-parent existence check, so it is always YES and the file-extension check is skipped.

## Repro

`allowedFileExtensions = ["txt"]`, then COPY `a.txt` → `b.exe`.

- Expected: 403
- Actual: 201

## Test

Known-issue test in `src/DZWebServersTests/`.
