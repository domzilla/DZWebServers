---
id: '261006-0R8M8XB'
title: JSON response initializers raise on invalid objects instead of returning nil
author: Dominic Rodemer
created_at: '2026-10-06T06:54:12.255499Z'
status: closed
labels:
- bug
---


> **Note:** Agent-generated from an automated doc/code review. This may be a false positive — analyze and confirm against the code before fixing.

## Parent

261006-0RVAHY0

`DZWebServerDataResponse.m:128` calls `NSJSONSerialization dataWithJSONObject:` without `isValidJSONObject:` first; invalid objects throw NSInvalidArgumentException rather than returning nil. Debug builds also hit `DWS_DNOT_REACHED()`.
Header docs (`DZWebServerDataResponse.h:143,157,212,228`) promise nil.
Fix: guard with `[NSJSONSerialization isValidJSONObject:object]` and return nil (drop the DNOT_REACHED).
