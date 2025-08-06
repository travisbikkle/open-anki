allprojects {
    repositories {
        // 添加国内镜像源
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        maven { url = uri("https://mirrors.tuna.tsinghua.edu.cn/maven/") }

        // 添加备用镜像源（华为云）
        maven { url = uri("https://repo.huaweicloud.com/repository/maven/") }

        // 保留原始仓库（镜像失效时备用）
        google()
        mavenCentral()

        // 添加Flutter插件仓库镜像
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
