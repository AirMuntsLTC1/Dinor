# Keep Dart FFI native method lookups
-keep class io.flutter.** { *; }
-keep class com.dinor.** { *; }

# Native methods referenced from C++ via JNI are safe, but keep the loader
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Dinor's native FFI bridge
-keep class com.dinor.dinor.** { *; }

# Ignore missing Google Play Core classes (Fix for R8)
-dontwarn com.google.android.play.core.**
