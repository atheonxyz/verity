plugins {
    id("com.android.library") version "8.5.0"
    id("org.jetbrains.kotlin.android") version "1.9.24"
    id("maven-publish")
    signing
    id("com.gradleup.nmcp") version "1.4.4"
}

val publishedAbis = listOf("arm64-v8a")

android {
    namespace = "xyz.atheon.verity"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")

        ndk {
            abiFilters += publishedAbis
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    packaging {
        jniLibs {
            excludes += listOf("**/x86_64/*.so")
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test:runner:1.5.2")
}

publishing {
    publications {
        create<MavenPublication>("release") {
            groupId = "xyz.atheon"
            artifactId = "verity"
            version = "0.0.2"

            afterEvaluate {
                from(components["release"])
            }

            pom {
                name.set("Verity")
                description.set("Zero-knowledge proof SDK for Android — ProveKit and Barretenberg backends")
                url.set("https://github.com/atheonxyz/verity")

                licenses {
                    license {
                        name.set("Proprietary")
                        url.set("https://github.com/atheonxyz/verity")
                    }
                }

                developers {
                    developer {
                        id.set("atheon")
                        name.set("Atheon")
                        email.set("rose@atheon.xyz")
                    }
                }

                scm {
                    connection.set("scm:git:git://github.com/atheonxyz/verity.git")
                    developerConnection.set("scm:git:ssh://github.com/atheonxyz/verity.git")
                    url.set("https://github.com/atheonxyz/verity")
                }
            }
        }
    }

}

signing {
    useGpgCmd()
    sign(publishing.publications["release"])
}

nmcp {
    publishAllPublicationsToCentralPortal {
        username.set(findProperty("mavenCentralUsername") as String? ?: "")
        password.set(findProperty("mavenCentralPassword") as String? ?: "")
    }
}
