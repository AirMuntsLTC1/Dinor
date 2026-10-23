# Keep Dart FFI native method lookups
-keep class io.flutter.** { *; }
-keep class com.dinor.** { *; }

# Native methods referenced from C++ via JNI are safe, but keep the loader
-keepclasseswithmembernames class * {
    native <methods>;
}
