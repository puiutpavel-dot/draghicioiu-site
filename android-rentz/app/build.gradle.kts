plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Semnarea: în Codemagic, keystore-ul de upload vine din „Code signing identities”
// (CM_KEYSTORE_PATH, CM_KEYSTORE_PASSWORD, CM_KEY_ALIAS, CM_KEY_PASSWORD).
// Fără ele, release-ul se semnează cu cheia de debug (pentru emulator / capturi).
val keystorePath: String? = System.getenv("CM_KEYSTORE_PATH")

// Play cere un versionCode mereu mai mare; Codemagic dă BUILD_NUMBER.
val buildNumber: Int = (System.getenv("BUILD_NUMBER")?.toIntOrNull() ?: 0) + 1

android {
    namespace = "ro.draghicioiu.rentz"
    compileSdk = 36

    defaultConfig {
        applicationId = "ro.draghicioiu.rentz"
        minSdk = 26
        targetSdk = 36
        versionCode = buildNumber
        versionName = "1.0"
    }

    signingConfigs {
        if (keystorePath != null) {
            create("release") {
                storeFile = file(keystorePath)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = if (keystorePath != null) signingConfigs.getByName("release")
            else signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.06.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}
