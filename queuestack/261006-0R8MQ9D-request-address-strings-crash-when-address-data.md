---
id: '261006-0R8MQ9D'
title: Request address strings crash when address data is unset
author: Dominic Rodemer
created_at: '2026-10-06T06:54:12.243559Z'
status: open
labels:
- bug
---

> **Note:** Agent-generated from an automated doc/code review. This may be a false positive — analyze and confirm against the code before fixing.

`DZWebServerRequest.m:283-289` passes `_localAddressData.bytes` / `_remoteAddressData.bytes` straight to `DZWebServerStringFromSockAddr`, which dereferences `addr->sa_len` (`DZWebServerFunctions.m:245`).
Header (`DZWebServerRequest.h:305,334`) declares nullable and documents nil before the address is set, but a request not created by a connection (e.g. tests, custom match blocks) crashes with NULL deref.
Fix: return nil when the address data is nil.
