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

// `dynamic_color` 1.7.0 pins its own module to `compileSdkVersion 31`, which
// is older than the androidx artifacts it depends on, so the AAR metadata
// check fails the build before anything is compiled. compileSdk is only what
// a library builds *against* — minSdk and targetSdk are untouched, and the
// plugin itself is a single platform channel that needs nothing old.
//
// Registered from the root script so it runs before AGP's own afterEvaluate
// locks the DSL down. The name is checked *outside* the callback rather than
// inside it: `:app` is already evaluated by the block above, and registering
// an afterEvaluate on an evaluated project is an error.
//
// Scoped to the one project rather than every plugin: a second module hitting
// this should be looked at, not silently fixed.
subprojects {
    if (name == "dynamic_color") {
        afterEvaluate {
            val android = extensions.findByName("android")
            if (android is com.android.build.api.dsl.LibraryExtension) {
                android.compileSdk = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
