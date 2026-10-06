---
id: '261006-0R8MC6W'
title: FileResponse regular-file check uses S_IFREG mask instead of S_ISREG
author: Dominic Rodemer
created_at: '2026-10-06T06:54:12.219034Z'
status: open
labels:
- bug
---

> **Note:** Agent-generated from an automated doc/code review. This may be a false positive — analyze and confirm against the code before fixing.

`DZWebServerFileResponse.m:81` uses `!(info.st_mode & S_IFREG)`. S_IFREG is a bit pattern, not a mask, so sockets (S_IFSOCK) and symlinks (S_IFLNK, via lstat) pass the check.
Impact: init succeeds for non-regular files, later open/read fails or serves odd content.
Fix: use `!S_ISREG(info.st_mode)`.
