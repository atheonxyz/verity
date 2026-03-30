# Verity SDK — ProGuard/R8 consumer rules
# These rules are automatically applied to apps that depend on this SDK.

# Keep all public API classes and members
-keep class com.atheon.verity.Verity { *; }
-keep class com.atheon.verity.Backend { *; }
-keep class com.atheon.verity.PreparedScheme { *; }
-keep class com.atheon.verity.ProverScheme { *; }
-keep class com.atheon.verity.VerifierScheme { *; }
-keep class com.atheon.verity.VerityException { *; }
-keep class com.atheon.verity.VerityException$* { *; }
-keep class com.atheon.verity.Circuit { *; }
-keep class com.atheon.verity.Proof { *; }
-keep class com.atheon.verity.Witness { *; }
-keep class com.atheon.verity.Witness$* { *; }
-keep class com.atheon.verity.MemoryStats { *; }

# Keep JNI native methods (R8 strips them without this)
-keepclasseswithmembernames class * {
    native <methods>;
}
