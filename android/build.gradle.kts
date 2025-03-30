// buildscript {
//     repositories {
//         google()
//         mavenCentral()
//     }
//     dependencies {
//         classpath("com.android.tools.build:gradle:8.1.0")
//         classpath("com.google.gms:google-services:4.4.2")
//         classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.10") 
//     }
// }

// plugins {
//     id("com.android.application") apply false
//     id("com.google.gms.google-services") version "4.4.2" apply false
// }

// allprojects { 
//     repositories {
//         google()
//         mavenCentral()
//     }
// }

// val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
// rootProject.layout.buildDirectory.value(newBuildDir)

// subprojects {
//     val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
//     project.layout.buildDirectory.value(newSubprojectBuildDir)
// }
// subprojects {
//     project.evaluationDependsOn(":app")
// }

// tasks.register<Delete>("clean") {
//     delete(rootProject.layout.buildDirectory)
// }

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.1.0")  // Updated version
        classpath("com.google.gms:google-services:4.3.15")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22")  // Updated version
    }
}

plugins {
    id("com.android.application") apply false
    id("com.google.gms.google-services") version "4.3.15" apply false
}

allprojects { 
    repositories {
        google()
        mavenCentral()
    }
    
    tasks.withType<JavaCompile> {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
    
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
        kotlinOptions {
            jvmTarget = JavaVersion.VERSION_17.toString()
        }
    }
}

// Simplified build directory configuration
rootProject.buildDir = File(rootProject.projectDir, "../build")

subprojects {
    project.buildDir = File(rootProject.buildDir, project.name)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}