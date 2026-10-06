---
id: '261006-0R8ME3Y'
title: Date functions crash if called before DZWebServer is initialized
author: Dominic Rodemer
created_at: '2026-10-06T06:54:12.291809Z'
status: open
labels:
- bug
---

> **Note:** Agent-generated from an automated doc/code review. This may be a false positive — analyze and confirm against the code before fixing.

## Parent

261006-0RVAHY0

Public `DZWebServerFormatRFC822/ParseRFC822/FormatISO8601/ParseISO8601` (`DZWebServerFunctions.m:122-150`) `dispatch_sync` on `_dateFormatterQueue`, which is only created in `DZWebServerInitializeFunctions()` from `+[DZWebServer initialize]` (`DZWebServer.m:181`).
Calling them before the DZWebServer class is touched dispatches onto NULL -> crash.
Fix: lazily init via `dispatch_once` inside the functions (note main-thread DCHECK in init).
