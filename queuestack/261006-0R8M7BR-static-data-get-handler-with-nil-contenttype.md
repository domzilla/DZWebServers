---
id: '261006-0R8M7BR'
title: Static data GET handler with nil contentType sends no body
author: Dominic Rodemer
created_at: '2026-10-06T06:54:12.267021Z'
status: open
labels:
- bug
---

> **Note:** Agent-generated from an automated doc/code review. This may be a false positive — analyze and confirm against the code before fixing.

## Parent

261006-0RVAHY0

`DZWebServer.m:983-991` forwards a nil `contentType` to `DZWebServerDataResponse`; `DZWebServerResponse.hasBody` is `_contentType != nil` (`DZWebServerResponse.m:177`), so the data is silently dropped.
Header (`DZWebServer.h:937,943`) explicitly allows nil.
Fix: fall back to `application/octet-stream` (or derive), or make the parameter nonnull.
