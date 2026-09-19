allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirects every module's build output into the top-level Flutter project's
// build/ directory (mobile_app/build/<module>) instead of each module's own
// android/<module>/build — this is what flutter run/build actually look under
// when locating the produced APK. Standard in Flutter's own project template;
// was missing here, so `flutter run` couldn't find a build that gradlew itself
// completed successfully.
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
