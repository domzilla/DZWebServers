---
id: '261005-1NRTKK9'
title: 'Port 0: IPv6 bound to IPv4''s ephemeral port without checking (EADDRINUSE)'
author: Dominic Rodemer
created_at: '2026-10-05T15:17:46.383233Z'
status: open
labels:
- bug
---

> **Note:** Produced during an autonomous agent run (test-suite review, 2026-10-05) and not verified by a human. This may be totally wrong — analyze and confirm before fixing.

## Parent

261006-0RVAHY0

## Problem

`DZWebServer.m:528-548`: when started with port 0, the OS picks a port for the IPv4 socket and the IPv6 socket is then bound to that same port, without that port being known free on IPv6. Intermittently fails with `EADDRINUSE`; this happened for real during the test runs.

## Workaround in tests

The `TestSupport.start` helper in `src/DZWebServersTests/` retries on `EADDRINUSE`. Its doc comment refers to this bug. Remove the retry once fixed.

## Test

No known-issue test, because the bug is non-deterministic.
