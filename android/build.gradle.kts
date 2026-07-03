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

// Reproducible builds: disable NDK build-id generation for native CMake-based
// dependencies (flutter_zxing, jni) instead of patching their vendored
// CMakeLists.txt from the F-Droid build recipe.
// See https://f-droid.org/docs/Reproducible_Builds/#cmake
//
// NB: this must live in the root build.gradle.kts (not android/app/build.gradle.kts)
// because `subprojects` refers to subprojects of the *current* project, and
// flutter_zxing/jni are subprojects of the root project, not of :app.
val nativeLibraryModulesWithBuildId = setOf("flutter_zxing", "jni")
subprojects {
    plugins.withId("com.android.library") {
        if (name in nativeLibraryModulesWithBuildId) {
            extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                defaultConfig {
                    externalNativeBuild {
                        cmake {
                            arguments += "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--build-id=none"
                        }
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
