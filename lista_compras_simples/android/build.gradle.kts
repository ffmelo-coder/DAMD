import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import com.android.build.gradle.BaseExtension

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

        afterEvaluate {
            if (project.plugins.hasPlugin("com.android.library") || project.plugins.hasPlugin("com.android.application")) {
                try {
                    val androidExt = project.extensions.getByName("android") as BaseExtension
                    androidExt.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
                    androidExt.compileOptions.targetCompatibility = JavaVersion.VERSION_17
                    project.extensions.findByName("kotlinOptions")?.let { ko ->
                        try {
                            ko.javaClass.getMethod("setJvmTarget", String::class.java).invoke(ko, "17")
                        } catch (_: Throwable) {
                            // ignore
                        }
                    }
                } catch (e: Throwable) {
                    println("[build.gradle.kts] failed to set android compileOptions for project ${project.name}: ${e.message}")
                }
            }
        }

    tasks.withType(JavaCompile::class.java).configureEach {
           sourceCompatibility = JavaVersion.VERSION_17.toString()
           targetCompatibility = JavaVersion.VERSION_17.toString()
        options.compilerArgs.addAll(listOf("-Xlint:-options"))
    }

    tasks.withType(KotlinCompile::class.java).configureEach {
           kotlinOptions.jvmTarget = "17"
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
