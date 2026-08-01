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

// home_widget 0.9.0 compiles its Kotlin with JVM target 11 (its dependencies
// ship 11-target bytecode that can't inline into 1.8). Force Kotlin to 11 for
// every subproject. Its Java compile stays at AGP's default (1.8); the resulting
// Java/Kotlin target mismatch is downgraded from error to warning via
// kotlin.jvm.target.validation.mode=warning in gradle.properties. Mixing is safe
// here because core-library desugaring is enabled.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = JavaVersion.VERSION_11.toString()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}