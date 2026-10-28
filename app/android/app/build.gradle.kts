import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.overworld.overworld"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.overworld.maps"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Share-link domain for App Links (see AndroidManifest.xml and docs/).
        manifestPlaceholders["shareHost"] = (project.findProperty("overworld.shareHost") ?: "phreak971.github.io").toString()
        manifestPlaceholders["sharePathPrefix"] = (project.findProperty("overworld.sharePathPrefix") ?: "/test/p").toString()
    }

    // Release signing from android/key.properties or OVERWORLD_* environment
    // variables (CI). A stable key lets installs update in place and is what
    // assetlinks.json vouches for. Without one, release builds use the debug key.
    val keyProps = Properties().apply {
        val f = rootProject.file("key.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }
    fun signingValue(prop: String, env: String): String? = keyProps.getProperty(prop) ?: System.getenv(env)
    val storePath = signingValue("storeFile", "OVERWORLD_KEYSTORE")
    signingConfigs {
        if (storePath != null && file(storePath).exists()) {
            create("release") {
                storeFile = file(storePath)
                storePassword = signingValue("storePassword", "OVERWORLD_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "OVERWORLD_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "OVERWORLD_KEY_PASSWORD")
            }
        }
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
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

dependencies {
    // Android Auto (androidx.car.app) navigation templates + map surface.
    implementation("androidx.car.app:app:1.7.0")
    // MapLibre Native for the car map. Same artifact/version the maplibre_gl
    // plugin uses (it declares it as `implementation`, so it is not on the
    // app's compile classpath by itself).
    implementation("org.maplibre.gl:android-sdk-opengl:13.5.0")

    testImplementation("junit:junit:4.13.2")
    // Real org.json for JVM unit tests (android.jar only ships stubs).
    testImplementation("org.json:json:20250517")
}
