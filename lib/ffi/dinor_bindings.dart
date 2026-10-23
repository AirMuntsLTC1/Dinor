import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef _VersionC = Pointer<Utf8> Function();
typedef _VersionD = Pointer<Utf8> Function();

typedef _EncryptC = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _EncryptD = int Function(Pointer<Utf8>, Pointer<Utf8>, int);

typedef _SearchC = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _SearchD = int Function(Pointer<Utf8>, Pointer<Utf8>);

typedef _FormatC = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _FormatD = int Function(Pointer<Utf8>, Pointer<Utf8>, int);

class DinorCore {
  final DynamicLibrary _lib;
  DinorCore._(this._lib);

  factory DinorCore.load() =>
      DinorCore._(DynamicLibrary.open('libdinor_core.so'));

  String version() {
    final fn = _lib.lookupFunction<_VersionC, _VersionD>('dinor_version');
    return fn().toDartString();
  }

  String encrypt(String text) {
    final fn = _lib.lookupFunction<_EncryptC, _EncryptD>('dinor_encrypt');
    final input = text.toNativeUtf8();
    final out = calloc<Uint8>(text.length + 1).cast<Utf8>();
    final n = fn(input, out, text.length + 1);
    final result = n < 0 ? '' : out.toDartString();
    calloc.free(input);
    calloc.free(out);
    return result;
  }

  // New: Search using C++
  bool search(String haystack, String needle) {
    final fn = _lib.lookupFunction<_SearchC, _SearchD>('dinor_fast_search');
    final h = haystack.toNativeUtf8();
    final n = needle.toNativeUtf8();
    final result = fn(h, n);
    calloc.free(h);
    calloc.free(n);
    return result == 1;
  }

  // New: Format text using C++
  String formatMessage(String text) {
    final fn = _lib.lookupFunction<_FormatC, _FormatD>('dinor_format_message');
    final input = text.toNativeUtf8();
    final out = calloc<Uint8>(text.length + 2).cast<Utf8>();
    final n = fn(input, out, text.length + 2);
    final result = n < 0 ? text : out.toDartString();
    calloc.free(input);
    calloc.free(out);
    return result;
  }
}
