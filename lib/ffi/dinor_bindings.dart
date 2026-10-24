import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

// ---- C signatures ----------------------------------------------------------
typedef _VersionC = Pointer<Utf8> Function();
typedef _VersionD = Pointer<Utf8> Function();

typedef _Utf8LenC = Int32 Function(Pointer<Utf8>);
typedef _Utf8LenD = int Function(Pointer<Utf8>);

typedef _TextFnC = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _TextFnD = int Function(Pointer<Utf8>, Pointer<Utf8>, int);

typedef _SearchC = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _SearchD = int Function(Pointer<Utf8>, Pointer<Utf8>);

typedef _ExtractC = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _ExtractD = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);

typedef _HashC = Int32 Function(Pointer<Utf8>);
typedef _HashD = int Function(Pointer<Utf8>);

typedef _AnimationC = Float Function(Double, Int32);
typedef _AnimationD = double Function(double, int);

typedef _StatusC = Pointer<Utf8> Function(Int32);
typedef _StatusD = Pointer<Utf8> Function(int);

typedef _TimestampC = Int64 Function();
typedef _TimestampD = int Function();

typedef _StaleC = Int32 Function(Int64, Int64, Int64);
typedef _StaleD = int Function(int, int, int);

typedef _RetryC = Int64 Function(Int32, Int64, Int64);
typedef _RetryD = int Function(int, int, int);

/// Thin, cached wrapper around libdinor_core.so.
///
/// * One library handle for the whole app (never reopened per frame).
/// * Buffers are sized from UTF-8 byte length, not Dart's UTF-16 length.
/// * If the native library is missing, every method falls back to pure Dart
///   so the app keeps working instead of crashing.
class DinorCore {
  DinorCore._(DynamicLibrary? lib)
      : _lib = lib,
        _version = lib == null ? null : _try(() => lib.lookupFunction<_VersionC, _VersionD>('dinor_version')),
        _utf8Len = lib == null ? null : _try(() => lib.lookupFunction<_Utf8LenC, _Utf8LenD>('dinor_utf8_length')),
        _encrypt = lib == null ? null : _try(() => lib.lookupFunction<_TextFnC, _TextFnD>('dinor_encrypt')),
        _format = lib == null ? null : _try(() => lib.lookupFunction<_TextFnC, _TextFnD>('dinor_format_message')),
        _sanitize = lib == null ? null : _try(() => lib.lookupFunction<_TextFnC, _TextFnD>('dinor_sanitize_input')),
        _batchSanitize = lib == null ? null : _try(() => lib.lookupFunction<_TextFnC, _TextFnD>('dinor_batch_sanitize')),
        _escapeLike = lib == null ? null : _try(() => lib.lookupFunction<_TextFnC, _TextFnD>('dinor_escape_like')),
        _search = lib == null ? null : _try(() => lib.lookupFunction<_SearchC, _SearchD>('dinor_fast_search')),
        _extract = lib == null ? null : _try(() => lib.lookupFunction<_ExtractC, _ExtractD>('dinor_extract_web_answer')),
        _hash = lib == null ? null : _try(() => lib.lookupFunction<_HashC, _HashD>('dinor_calculate_hash')),
        _animation = lib == null ? null : _try(() => lib.lookupFunction<_AnimationC, _AnimationD>('dinor_animation_scale')),
        _status = lib == null ? null : _try(() => lib.lookupFunction<_StatusC, _StatusD>('dinor_get_status_icon')),
        _timestamp = lib == null ? null : _try(() => lib.lookupFunction<_TimestampC, _TimestampD>('dinor_fast_timestamp')),
        _stale = lib == null ? null : _try(() => lib.lookupFunction<_StaleC, _StaleD>('dinor_is_stale')),
        _retry = lib == null ? null : _try(() => lib.lookupFunction<_RetryC, _RetryD>('dinor_retry_delay_ms'));

  static DinorCore? _instance;

  /// Looks up one symbol; a missing symbol yields null (Dart fallback) instead of throwing.
  static T? _try<T>(T Function() lookup) {
    try {
      return lookup();
    } catch (_) {
      return null;
    }
  }

  final DynamicLibrary? _lib;

  final _VersionD? _version;
  final _Utf8LenD? _utf8Len;
  final _TextFnD? _encrypt;
  final _TextFnD? _format;
  final _TextFnD? _sanitize;
  final _TextFnD? _batchSanitize;
  final _TextFnD? _escapeLike;
  final _SearchD? _search;
  final _ExtractD? _extract;
  final _HashD? _hash;
  final _AnimationD? _animation;
  final _StatusD? _status;
  final _TimestampD? _timestamp;
  final _StaleD? _stale;
  final _RetryD? _retry;

  /// True when libdinor_core.so loaded successfully.
  bool get isNative => _lib != null;

  /// Returns the shared instance. Safe to call on every frame: it is cached,
  /// and the library is opened at most once per app run.
  factory DinorCore.load() {
    final existing = _instance;
    if (existing != null) return existing;
    DynamicLibrary? lib;
    try {
      lib = DynamicLibrary.open('libdinor_core.so');
    } catch (_) {
      lib = null; // no native library: use Dart implementations
    }
    return _instance = DinorCore._(lib);
  }

  // ---- helpers -------------------------------------------------------------
  static int _bytes(String s) => utf8.encode(s).length;

  String _runText(_TextFnD? fn, String input, {int? outFactor}) {
    if (fn == null) return input;
    final inPtr = input.toNativeUtf8();
    final outSize = _bytes(input) * (outFactor ?? 1) + 1;
    final out = calloc<Uint8>(outSize).cast<Utf8>();
    try {
      final n = fn(inPtr, out, outSize);
      return n < 0 ? input : out.toDartString();
    } finally {
      calloc.free(inPtr);
      calloc.free(out);
    }
  }

  // ---- identity ------------------------------------------------------------
  String version() {
    if (_version == null) return 'Dinor (Dart fallback)';
    return _version().toDartString();
  }

  int utf8Length(String text) {
    if (_utf8Len == null) return _bytes(text);
    final p = text.toNativeUtf8();
    try {
      return _utf8Len(p);
    } finally {
      calloc.free(p);
    }
  }

  // ---- text ----------------------------------------------------------------
  /// Reversible obfuscation (not encryption) kept for compatibility.
  String encrypt(String text) {
    if (_encrypt == null) return String.fromCharCodes(text.runes.toList().reversed);
    return _runText(_encrypt, text);
  }

  bool search(String haystack, String needle) {
    if (_search == null) {
      return haystack.toLowerCase().contains(needle.toLowerCase());
    }
    final h = haystack.toNativeUtf8();
    final n = needle.toNativeUtf8();
    try {
      return _search(h, n) == 1;
    } finally {
      calloc.free(h);
      calloc.free(n);
    }
  }

  String extractAiAnswer(String query, String webText) {
    if (_extract == null) return '';
    final q = query.toNativeUtf8();
    final w = webText.toNativeUtf8();
    const outSize = 512;
    final out = calloc<Uint8>(outSize).cast<Utf8>();
    try {
      final n = _extract(q, w, out, outSize);
      return n < 0 ? '' : out.toDartString();
    } finally {
      calloc.free(q);
      calloc.free(w);
      calloc.free(out);
    }
  }

  String sanitizeInput(String text) {
    if (_sanitize == null) {
      return text.replaceAll(RegExp(r'[\u0000-\u0009\u000B-\u001F\u007F]'), '');
    }
    return _runText(_sanitize, text);
  }

  /// Sanitizes, collapses whitespace and trims. Used before every send.
  String batchSanitize(String text) {
    if (_batchSanitize == null) {
      return text.replaceAll(RegExp(r'[\r\n\t]+'), ' ').replaceAll(RegExp(r' {2,}'), ' ').trim();
    }
    return _runText(_batchSanitize, text);
  }

  String escapeLike(String text) {
    if (_escapeLike == null) {
      return text.replaceAllMapped(RegExp(r'[%_\\]'), (m) => '\\${m[0]}');
    }
    return _runText(_escapeLike, text, outFactor: 2);
  }

  String formatMessage(String text) => _runText(_format, text);

  int calculateHash(String text) {
    if (_hash == null) {
      var h = 5381;
      for (final c in utf8.encode(text)) {
        h = ((h << 5) + h + c) & 0x7FFFFFFF;
      }
      return h;
    }
    final p = text.toNativeUtf8();
    try {
      return _hash(p);
    } finally {
      calloc.free(p);
    }
  }

  // ---- timing / cache ------------------------------------------------------
  int getFastTimestamp() {
    if (_timestamp == null) return DateTime.now().millisecondsSinceEpoch;
    return _timestamp();
  }

  /// True when a cache entry saved at [savedAtMs] is older than [ttlMs].
  bool isStale({required int savedAtMs, required int ttlMs, int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (_stale == null) {
      if (savedAtMs <= 0 || ttlMs <= 0 || now < savedAtMs) return true;
      return now - savedAtMs > ttlMs;
    }
    return _stale(savedAtMs, ttlMs, now) == 1;
  }

  /// Exponential backoff delay in ms for retry [attempt] (0-based).
  int retryDelayMs(int attempt, {int baseMs = 250, int capMs = 4000}) {
    if (_retry == null) {
      final shift = attempt < 0 ? 0 : (attempt > 30 ? 30 : attempt);
      final d = baseMs * (1 << shift);
      return d > capMs ? capMs : d;
    }
    return _retry(attempt, baseMs, capMs);
  }

  // ---- animation / status --------------------------------------------------
  double getAnimationScale(double timeSeconds, int dotIndex) {
    if (_animation == null) {
      final delay = dotIndex * 0.2;
      var progress = (timeSeconds - delay) % 1.0;
      if (progress < 0) progress += 1.0;
      return 1.0 + (0.6 * (progress < 0.5 ? progress * 2 : (1 - progress) * 2));
    }
    return _animation(timeSeconds, dotIndex);
  }

  String getStatusIcon(int statusCode) {
    if (_status == null) {
      switch (statusCode) {
        case 0: return 'sending';
        case 1: return 'sent';
        case 2: return 'failed';
        default: return 'unknown';
      }
    }
    return _status(statusCode).toDartString();
  }
}
