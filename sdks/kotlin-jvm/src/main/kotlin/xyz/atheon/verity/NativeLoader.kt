package xyz.atheon.verity

import java.io.File
import java.io.InputStream

internal object NativeLoader {
    private var loaded = false

    @Synchronized
    fun load() {
        if (loaded) return
        val (os, arch) = detectPlatform()
        val ext = if (os == "darwin") "dylib" else "so"
        val libName = "libverity_jni.$ext"
        val resourcePath = "native/$os-$arch/$libName"

        val input: InputStream = NativeLoader::class.java.classLoader
            ?.getResourceAsStream(resourcePath)
            ?: throw UnsatisfiedLinkError("Native library not found in JAR: $resourcePath")

        val tempDir = File(System.getProperty("java.io.tmpdir"), "verity-native")
        tempDir.mkdirs()
        val tempFile = File(tempDir, libName)

        input.use { src ->
            tempFile.outputStream().use { dst -> src.copyTo(dst) }
        }

        System.load(tempFile.absolutePath)
        loaded = true
    }

    private fun detectPlatform(): Pair<String, String> {
        val osName = System.getProperty("os.name").lowercase()
        val archName = System.getProperty("os.arch").lowercase()

        val os = when {
            osName.contains("mac") || osName.contains("darwin") -> "darwin"
            osName.contains("linux") -> "linux"
            else -> throw UnsatisfiedLinkError("Unsupported OS: $osName")
        }

        val arch = when {
            archName == "aarch64" || archName == "arm64" -> "aarch64"
            archName == "x86_64" || archName == "amd64" -> "x86_64"
            else -> throw UnsatisfiedLinkError("Unsupported architecture: $archName")
        }

        return os to arch
    }
}
