plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.FileInputStream
import java.util.Properties

android {
    namespace = "com.example.stock"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.stock"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Task to generate google-services.json from environment variables
    task("generateGoogleServicesJson") {
        doLast {
            // .env.local is in the Frontend directory (use absolute path)
            val envFile = File("C:\\Users\\tngh8\\Frontend\\.env.local")
            val properties = Properties()

            if (envFile.exists()) {
                FileInputStream(envFile).use { input ->
                    properties.load(input)
                }
            } else {
                println("Warning: .env.local file not found at ${envFile.absolutePath}. Please create it with Firebase credentials.")
                return@doLast
            }

            val googleServicesDir = File(projectDir, "src")
            val googleServicesFile = File(googleServicesDir, "google-services.json")

            // Create directory if it doesn't exist
            googleServicesDir.mkdirs()

            // Template google-services.json with placeholders
            val template = """
            {
              "project_info": {
                "project_number": "${properties.getProperty("FIREBASE_PROJECT_NUMBER", "")}",
                "project_id": "${properties.getProperty("FIREBASE_PROJECT_ID", "")}",
                "storage_bucket": "${properties.getProperty("FIREBASE_STORAGE_BUCKET", "")}"
              },
              "client": [
                {
                  "client_info": {
                    "mobilesdk_app_id": "${properties.getProperty("FIREBASE_MOBILESDK_APP_ID", "")}",
                    "android_client_info": {
                      "package_name": "com.example.stock"
                    }
                  },
                  "oauth_client": [
                    {
                      "client_id": "${properties.getProperty("FIREBASE_CLIENT_ID", "")}",
                      "client_type": 1,
                      "android_info": {
                        "package_name": "com.example.stock",
                        "certificate_hash": "55fb45c8acef94d2a54058178a0d519c755d0d00"
                      }
                    },
                    {
                      "client_id": "${properties.getProperty("FIREBASE_CLIENT_ID_ANDROID_CERT2", "")}",
                      "client_type": 1,
                      "android_info": {
                        "package_name": "com.example.stock",
                        "certificate_hash": "d52e9f312ed2c8da8edfb491a694f744f7288df3"
                      }
                    },
                    {
                      "client_id": "${properties.getProperty("FIREBASE_CLIENT_ID_WEB", "")}",
                      "client_type": 3
                    }
                  ],
                  "api_key": [
                    {
                      "current_key": "${properties.getProperty("FIREBASE_API_KEY", "")}"
                    }
                  ],
                  "services": {
                    "appinvite_service": {
                      "other_platform_oauth_client": [
                        {
                          "client_id": "${properties.getProperty("FIREBASE_CLIENT_ID_WEB", "")}",
                          "client_type": 3
                        },
                        {
                          "client_id": "${properties.getProperty("FIREBASE_IOS_CLIENT_ID", "")}",
                          "client_type": 2,
                          "ios_info": {
                            "bundle_id": "com.example.stock.gnnproject"
                          }
                        }
                      ]
                    }
                  }
                }
              ],
              "configuration_version": "1"
            }
            """.trimIndent()

            googleServicesFile.writeText(template)
            println("Generated google-services.json with environment variables")
        }
    }

    // Make sure the generation happens before the app is compiled
    tasks.named("preBuild") {
        dependsOn("generateGoogleServicesJson")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
