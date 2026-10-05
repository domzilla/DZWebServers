---
id: '261005-1NRT3NF'
title: Error response HTML only escapes quotes (reflected XSS)
author: Dominic Rodemer
created_at: '2026-10-05T15:17:46.272173Z'
status: open
labels:
- bug
---

> **Note:** Produced during an autonomous agent run (test-suite review, 2026-10-05) and not verified by a human. This may be totally wrong — analyze and confirm before fixing.

## Problem

`_EscapeHTMLString` in `src/DZWebServers/Classes/Data/Responses/DZWebServerErrorResponse.m:93` only replaces `"` with `&quot;`. `<`, `>` and `&` in the message or the underlying error's description go into the HTML unescaped. `DZWebUploader.m` builds error messages from user-controlled paths and file names, so a crafted request path can inject markup or script into the error page (reflected XSS).

## Fix idea

Escape `&` (first), `<`, `>`, `"` and `'`.

## Test

Known-issue test in `src/DZWebServersTests/`.
