import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Unconfigured development builds still support all in-app features.
// The intended Firebase project's ignored config enables native/background FCM.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val releaseProperties = Properties()
val releasePropertiesFile = rootProject.file("key.properties")
if (releasePropertiesFile.exists()) {
    releasePropertiesFile.inputStream().use { releaseProperties.load(it) }
}
val releaseKeys = mapOf(
    "storeFile" to "HOMECIRCLE_KEYSTORE_FILE",
    "storePassword" to "HOMECIRCLE_STORE_PASSWORD",
    "keyAlias" to "HOMECIRCLE_KEY_ALIAS",
    "keyPassword" to "HOMECIRCLE_KEY_PASSWORD",
).mapValues { (property, environment) ->
    System.getenv(environment)?.takeIf { it.isNotBlank() }
        ?: releaseProperties.getProperty(property)?.takeIf { it.isNotBlank() }
}
val hasReleaseKeys = releaseKeys.values.all { it != null }
if (releaseKeys.values.any { it != null } && !hasReleaseKeys &&
    gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }) {
    error("Release signing configuration is incomplete. Supply all four signing fields.")
}

android {
    namespace = "com.homecircle.homecircle"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.homecircle.homecircle"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeys) {
            create("release") {
                storeFile = rootProject.file(releaseKeys.getValue("storeFile")!!)
                storePassword = releaseKeys.getValue("storePassword")
                keyAlias = releaseKeys.getValue("keyAlias")
                keyPassword = releaseKeys.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKeys) signingConfig = signingConfigs.getByName("release")
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
