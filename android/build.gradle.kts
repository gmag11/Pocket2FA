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

// Reproducible builds for native CMake-based dependencies (flutter_zxing, jni).
// - Disable NDK build-id generation (--build-id=none).
// - Normalize embedded source paths (-ffile-prefix-map) so compiled .so files
//   are byte-identical regardless of the build machine's absolute paths.
// Both flags are applied here in Gradle so that local builds, CI builds, and
// the F-Droid recipe all use the same mechanism without patching vendored
// CMakeLists.txt.
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
                            arguments += "-DCMAKE_C_FLAGS=-ffile-prefix-map=\${CMAKE_SOURCE_DIR}=."
                            arguments += "-DCMAKE_CXX_FLAGS=-ffile-prefix-map=\${CMAKE_SOURCE_DIR}=."
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
