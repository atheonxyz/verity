# Verity SDK — ProGuard/R8 consumer rules
# These rules are automatically applied to apps that depend on this SDK.

# Keep all public API classes and members
-keep class xyz.atheon.verity.Verity { *; }
-keep class xyz.atheon.verity.Backend { *; }
-keep class xyz.atheon.verity.PreparedScheme { *; }
-keep class xyz.atheon.verity.ProverScheme { *; }
-keep class xyz.atheon.verity.VerifierScheme { *; }
-keep class xyz.atheon.verity.VerityException { *; }
-keep class xyz.atheon.verity.VerityException$* { *; }
-keep class xyz.atheon.verity.Circuit { *; }
-keep class xyz.atheon.verity.Proof { *; }
-keep class xyz.atheon.verity.Witness { *; }
-keep class xyz.atheon.verity.Witness$* { *; }
-keep class xyz.atheon.verity.MemoryStats { *; }

# Keep JNI native methods (R8 strips them without this)
-keepclasseswithmembernames class * {
    native <methods>;
}
