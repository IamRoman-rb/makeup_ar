allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// --- FIX NAMESPACE Y SDK PARA DEEPAR E IMAGE PICKER ---
subprojects {
    afterEvaluate {
        if (hasProperty("android")) {
            configure<com.android.build.gradle.BaseExtension> {
                // FORZAR SDK VERSIONS EN TODOS LOS PLUGINS (Sintaxis Kotlin)
                compileSdkVersion(36)
                defaultConfig.minSdk = 24
                defaultConfig.targetSdk = 36

                if (namespace == null) {
                    val fallbackNamespace = group.toString()
                    if (fallbackNamespace.isNotEmpty()) {
                        namespace = fallbackNamespace
                    }
                }
            }
        }
    }
}
// ------------------------------------------------------------------------

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}