import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef _VersionC = Pointer<Utf8> Function();
typedef _VersionD = Pointer<Utf8> Function();
typedef _EncryptC = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _EncryptD = int Function(Pointer<Utf8>, Pointer<Utf8>, int);

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
}
