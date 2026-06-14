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
// Force every Android module (app + Flutter plugins) onto the already-installed NDK.
// Flutter 3.44.1's default (28.2.13676358) only exists as a corrupt/partial download here
// and re-fetching the ~1GB package through the proxy stalls. 27.1.12297006 is installed intact.
// Registered before evaluationDependsOn below so the callback is in place before evaluation.
subprojects {
    // afterEvaluate (not withPlugin) so this runs AFTER each plugin's own build script,
    // overriding values plugins hardcode for themselves (e.g. file_picker pins compileSdk 34).
    // Registered before evaluationDependsOn(":app") below so :app isn't yet evaluated here.
    afterEvaluate {
        (extensions.findByName("android") as? com.android.build.gradle.BaseExtension)?.apply {
            ndkVersion = "27.1.12297006"
            compileSdkVersion(36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
