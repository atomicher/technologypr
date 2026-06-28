plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    // Додано плагін Google Services
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.document_sign_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.document_sign_app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Додано блок залежностей для Firebase / Google бібліотек
dependencies {
    // Керування версіями Firebase за допомогою BoM
    implementation(platform("com.google.firebase:firebase-bom:33.1.1"))
    
    // Приклад підключення аналітики (додайте інші за потреби, наприклад firebase-auth)
    implementation("com.google.firebase:firebase-analytics")
}