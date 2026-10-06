---
id: '261006-0R8M0NR'
title: Failed request body read still processes request with truncated body
author: Dominic Rodemer
created_at: '2026-10-06T06:54:12.231644Z'
status: open
labels:
- bug
---

> **Note:** Agent-generated from an automated doc/code review. This may be a false positive — analyze and confirm against the code before fixing.

`DZWebServerConnection.m:236-243` and `:264-273`: completion blocks of `readBodyWithRemainingLength:` / `readNextBodyChunk:` ignore `success`; on read error or `performWriteData` failure the request is still closed and processed.
Impact: handlers run with a truncated/partial body (e.g. partial uploads saved as complete).
Fix: if `!success`, abort the request (e.g. 400/500) instead of calling `_startProcessingRequest`. (Also: log uses outer `error` instead of `localError`.)
