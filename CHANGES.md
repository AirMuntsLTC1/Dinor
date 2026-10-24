# Dinor — update notes

This update targets the startup timing, local caching, calling, chat cache
timing, skeleton loading, frame drops, and the native C++ core.

## What changed

### Startup timing (lib/main.dart)
- The first frame is drawn immediately. Supabase init and the local cache
  preload run in parallel behind a splash, instead of blocking `runApp`.
- The auth gate uses the current session on the first frame, so there is no
  waiting spinner before the right screen appears.
- Startup failure shows a Retry button instead of a blank screen.

### Local cache timing (lib/chat/message_cache.dart)
- Conversations and messages are persisted with SharedPreferences and held
  in memory. The conversation list paints from cache at launch.
- Each entry has a `savedAt` timestamp. Stale entries still paint, then refresh
  in the background ("show first, refresh after").
- Message lists are capped (100 per chat, 30 chats), so the cache stays small.
- Sign-out clears the cache so the next account never sees old data.
- The old cache imported chat_screen (a circular dependency); it now stores
  plain rows.

### Chat (lib/ui/chat_screen.dart, lib/chat/chat_service.dart)
- Opening a chat paints its cached messages immediately.
- Realtime listens only to the current conversation (server-side filter), not
  every message in the app.
- Our own message echoing back over realtime no longer appears twice.
- A failed send keeps the user's text (it used to be replaced with "Failed to send").
- Deleted messages are removed from the cache too (they used to reappear).
- Unread counts are fetched in parallel (was one query per chat, in sequence).
- User search escapes `%` and `_`, so typed wildcards cannot match everything.

### Calling (lib/chat/call_service.dart, lib/ui/call_screen.dart)
- ICE candidates are written through a serial queue. Concurrent candidates
  used to overwrite each other.
- Remote candidates that arrive before the remote description are buffered.
- Signals written before the subscription went live (e.g. an answer) are read
  once on subscribe, so they are never missed.
- The screen shows real WebRTC state (Calling / Connecting / Connected with a
  timer). It used to fake "Connected" after 3 seconds.
- Incoming calls: the home screen shows an Answer / Decline prompt.
- Calls that are declined or unanswered for 45 seconds end cleanly. The
  caller logs the call (outgoing, missed, or declined).
- Full teardown on end, so the next call starts clean.

### Skeleton loading (lib/ui/skeleton_loader.dart)
- One shared shimmer system. The home list and the chat use it instead of spinners.

### Frame drops
- `DinorCore.load()` used to reopen the native library on every animation
  frame in the typing dots. It is now a cached singleton.

### Native C++ core (native/src, native/CMakeLists.txt)
- `native/CMakeLists.txt` is new. The Android build pointed at it, but it was
  missing from the project, so the native build failed.
- Fixed: case-insensitive search used a signed `tolower` (undefined behavior)
  and is now a correct substring match.
- Fixed: sanitizing could split a UTF-8 character when truncating.
- Fixed: Dart buffers were sized in UTF-16 units, not UTF-8 bytes, which could
  overflow with non-English text. They are now sized by byte length.
- New C-core functions: `dinor_utf8_length`, `dinor_escape_like`,
  `dinor_is_stale`, `dinor_retry_delay_ms`. Existing functions were hardened.
- Dart fallbacks: if the native library is missing, every call falls back to
  pure Dart, so the app does not crash.
- The C++ core was compiled with `-Wall -Wextra -Werror` and tested
  (UTF-8 truncation, search, escaping, cache TTL, backoff).

## How to verify (run these in Termux, then check GitHub Actions)
1. Unzip, then `cd` into the project folder.
2. `git add -A && git commit -m "startup, cache, calls, skeleton, native core" && git push`
3. Wait for the "Build Dinor APK" workflow to go green. It compiles the
   C++ core through Gradle/CMake.
4. Install the arm64 APK and test: cold start (list appears from cache),
   open a chat (messages appear instantly), send a message (no duplicate),
   call from one device to another (both sides show Connected).

## Known limits / to check
- Dart and Flutter were not available where this update was prepared, so the
  Dart code has been structurally checked but not compiled. CI will catch any
  compile errors; send me the log if it fails.
- Supabase Realtime must have `messages` and `calls` in the
  `supabase_realtime` publication (`calls` is added by migration).
- `supabase/migrations` has duplicate files for `create_calls_table` and
  `fix_read_receipts`. Applying both would fail on the second. They were left
  untouched.
- `dinor_encrypt` is reversible obfuscation, not encryption. It is kept for
  compatibility and is not used anywhere in the app.
- The call uses Google's public STUN server only. Calls behind strict NATs may
  need a TURN server.
