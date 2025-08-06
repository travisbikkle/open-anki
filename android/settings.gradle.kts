pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // 优先使用国内镜像
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        maven { url = uri("https://mirrors.huaweicloud.com/repository/maven/") }
        maven { url = uri("https://mirrors.cloud.tencent.com/gradle/") }

        // 保留原始仓库（镜像失效时备用）
        gradlePluginPortal()
        google()
        mavenCentral()

        // 添加Flutter插件仓库镜像
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.10" apply false
}

include(":app")
