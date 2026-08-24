import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Read once, at configuration time. Null when the file is absent, which is
// the normal state of a clone: the credentials live outside the repo and CI
// injects them.
val keystoreProperties: Properties? =
    rootProject.file("key.properties").takeIf { it.exists() }?.let { file ->
        Properties().apply { file.inputStream().use { load(it) } }
    }

android {
    namespace = "com.buzzjective.nearlystop"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // `flutter_local_notifications` uses `java.time`, which does not exist
        // below API 26. Without desugaring the app does not BUILD on this
        // project's minSdk — it is not a runtime nicety.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.buzzjective.nearlystop"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Present only when `android/key.properties` is — which is never in
        // this repo. See `docs/release/RELEASING.md`.
        if (keystoreProperties != null) {
            create("upload") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Null when the file is absent, which leaves the release build
            // UNSIGNED. Never a fallback to the debug key: a debug-signed
            // release uploads, installs, and can then never be updated by a
            // properly signed one — the signature is the app's identity to
            // Android, and that artifact is unrecoverable.
            //
            // The loud failure lives in the task-graph guard below rather than
            // here, because this block is CONFIGURED for every build including
            // `flutter run` — throwing here breaks a debug build on a machine
            // that has no signing material, which is every clone.
            signingConfig = signingConfigs.findByName("upload")

            // R8 on, because this is the first and only place reflective
            // plugin failures surface — see EPIC-15 task 9.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// The loud failure, at EXECUTION time and only for a release task. Gradle
// configures every build type on every invocation, so a throw inside the
// `release {}` block above would break `flutter run` on any clone.
gradle.taskGraph.whenReady {
    val releasing = allTasks.any { task ->
        task.project.path == ":app" &&
            (task.name.endsWith("Release") || task.name.endsWith("ReleaseBundle"))
    }
    if (releasing && keystoreProperties == null) {
        throw GradleException(
            "android/key.properties is missing, so this release build would " +
                "be UNSIGNED. Never sign a release with the debug key: that " +
                "artifact installs and can then never be updated on Play. " +
                "See docs/release/RELEASING.md."
        )
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
