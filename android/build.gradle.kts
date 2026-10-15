allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDirectory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDirectory)

subprojects {
    val newSubprojectBuildDirectory = newBuildDirectory.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDirectory)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

