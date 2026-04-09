plugins {
    kotlin("jvm") version "1.9.24"
    `maven-publish`
    signing
}

group = "xyz.atheon"
version = file("../../VERSION").readText().trim()

kotlin {
    jvmToolchain(11)
}

sourceSets {
    main {
        kotlin {
            srcDirs("src/main/kotlin")
        }
        resources {
            srcDirs("src/main/resources")
        }
    }
}

dependencies {
    implementation("org.json:json:20240303")
}

publishing {
    publications {
        create<MavenPublication>("jvm") {
            groupId = "xyz.atheon"
            artifactId = "verity-jvm"
            version = file("../../VERSION").readText().trim()

            from(components["java"])
        }
    }
    repositories {
        maven {
            name = "sonatype"
            url = uri("https://s01.oss.sonatype.org/service/local/staging/deploy/maven2/")
            credentials {
                username = findProperty("sonatypeUsername") as String? ?: ""
                password = findProperty("sonatypePassword") as String? ?: ""
            }
        }
    }
}

signing {
    val signingKey = findProperty("signingKey") as String?
    val signingPassword = findProperty("signingPassword") as String?
    if (signingKey != null && signingPassword != null) {
        useInMemoryPgpKeys(signingKey, signingPassword)
        sign(publishing.publications["jvm"])
    }
}
