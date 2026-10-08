---
id: '261006-0R8M31C'
title: Nonnull properties can be nil (DataRequest.data, form arguments, uploader strings)
author: Dominic Rodemer
created_at: '2026-10-06T06:54:12.305061Z'
status: closed
labels:
- bug
---


> **Note:** Agent-generated from an automated doc/code review. This may be a false positive — analyze and confirm against the code before fixing.

## Parent

261006-0RVAHY0

Declared nonnull (inside NS_ASSUME_NONNULL) but can be nil:
- `DZWebServerDataRequest.data` (`DZWebServerDataRequest.h:63`): only set in `-open:`, nil for requests without body.
- `DZWebServerURLEncodedFormRequest.arguments` (`.h:75`): only set in `-close:`, nil without body.
- `DZWebUploader` `title/header/prologue/footer` (`DZWebUploader.h:212-271`): docs say default nil, impl checks for nil (`DZWebUploader.m:94-118`).
Fix: mark nullable (or default data/arguments to empty values).
