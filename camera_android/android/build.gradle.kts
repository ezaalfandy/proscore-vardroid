allprojects {
    repositories {
        google()
        mavenCentral()

        // Uncomment ONLY if the FFmpegKit fork you use requires JitPack
        // maven { url = uri("https://jitpack.io") }
    }
}

/*
 |------------------------------------------------------------
 | Unified build directory (kept from your original setup)
 |------------------------------------------------------------
 */
val newBuildDir: Directory =
    rootProject.layout.buildDirectory.dir("../../build").get()

rootProject.layout.buildDirectory.value(newBuildDir)

/*
 |------------------------------------------------------------
 | Apply same build directory strategy to subprojects
 |------------------------------------------------------------
 */
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

/*
 |------------------------------------------------------------
 | Ensure :app evaluated first (Flutter requirement)
 |------------------------------------------------------------
 */
subprojects {
    project.evaluationDependsOn(":app")
}

/*
 |------------------------------------------------------------
 | Clean task
 |------------------------------------------------------------
 */
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
