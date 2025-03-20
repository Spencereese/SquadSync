plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.cod_squad_app"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true // Corrected syntax
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.cod_squad_app"
        minSdk = 23
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.2.0"))
    implementation("com.google.firebase:firebase-analytics")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

tasks.whenTaskAdded {
    if (name == "assembleDebug") {
        doLast {
            val sourceApk = file("$buildDir/outputs/apk/debug/app-debug.apk")
            val targetDir = file("${project.rootDir}/../build/app/outputs/flutter-apk")
            val targetApk = file("$targetDir/app-debug.apk")
            targetDir.mkdirs()
            if (sourceApk.exists()) {
                copy {
                    from(sourceApk)
                    into(targetDir)
                }
                println("Copied $sourceApk to $targetApk")
            } else {
                println("Source APK not found: $sourceApk")
            }
        }
    }
}