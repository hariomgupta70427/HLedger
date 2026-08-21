allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// firebase_auth compiles its Java at 17, and home_widget 0.9.0 ships Kotlin
// dependencies whose bytecode can't inline into a lower target. Pin Kotlin to 17
// for every subproject. Plugins whose Java compile stays on AGP's default are a
// target mismatch that kotlin.jvm.target.validation.mode=warning downgrades from
// error; mixing is safe here because core-library desugaring is enabled.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = JavaVersion.VERSION_17.toString()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}