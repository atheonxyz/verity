pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "VerityDemo"
include(":app")

// Local development: include the SDK from the monorepo
// For standalone use: remove these lines and use Maven dependency in app/build.gradle.kts
include(":verity")
project(":verity").projectDir = file("../../../sdks/kotlin")
