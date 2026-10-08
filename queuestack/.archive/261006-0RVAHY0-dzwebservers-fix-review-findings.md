---
id: '261006-0RVAHY0'
title: 'DZWebServers: fix review findings'
author: Dominic Rodemer
created_at: '2026-10-06T07:04:10.256476Z'
status: closed
labels:
- master
---


## Overview

Fix the bugs found by the 2026-10-05 test-suite review and the 2026-10-06 doc/code review. Each item is unverified and must be confirmed first. Once all sub-items are closed, the server has no known XSS or WebDAV extension bypass, no crashes or silently truncated or empty bodies, RFC-correct WebDAV status codes, and nullability annotations that match the implementation.

## Sub-items

Proposed sequence, top to bottom. Check off each sub-item when it is closed.

- [x] 261005-1NRT3NF — Error response HTML only escapes quotes (reflected XSS) (blocked by: none)
- [x] 261005-1NRTPZ2 — WebDAV COPY/MOVE ignore allowedFileExtensions (blocked by: none)
- [x] 261005-1NRT50D — WebDAV COPY of missing source returns 403 instead of 404 (blocked by: 261005-1NRTPZ2)
- [x] 261005-1NRTAKP — WebDAV COPY onto existing destination returns 403 (blocked by: none)
- [x] 261005-1NRT3WD — WebDAV MKCOL on existing collection returns 500 (blocked by: none)
- [x] 261006-0R8M0NR — Failed request body read still processes request with truncated body (blocked by: none)
- [x] 261006-0R8ME3Y — Date functions crash if called before DZWebServer is initialized (blocked by: none)
- [x] 261006-0R8MQ9D — Request address strings crash when address data is unset (blocked by: none)
- [x] 261006-0R8M8XB — JSON response initializers raise on invalid objects instead of returning nil (blocked by: none)
- [x] 261006-0R8MC6W — FileResponse regular-file check uses S_IFREG mask instead of S_ISREG (blocked by: none)
- [x] 261005-1NRTP54 — Streamed response with gzip enabled sends empty body (blocked by: none)
- [x] 261006-0R8M7BR — Static data GET handler with nil contentType sends no body (blocked by: none)
- [x] 261006-0R8MBVB — Directory handler index file ignores cacheAge and range requests (blocked by: none)
- [x] 261005-1NRTKK9 — Port 0: IPv6 bound to IPv4's ephemeral port without checking (EADDRINUSE) (blocked by: none)
- [x] 261005-1NRTB5E — URL-encoded form parser mishandles leading & and empty keys (blocked by: none)
- [x] 261006-0R8M31C — Nonnull properties can be nil (DataRequest.data, form arguments, uploader strings) (blocked by: none)
