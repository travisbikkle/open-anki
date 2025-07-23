# open_anki

### frb watch rust code
```
flutter_rust_bridge_codegen generate --watch
```

### Package manually
```
open ios/Runner.xcworkspace
flutter build ios --release
在 Xcode 菜单栏选择 Product → Archive。

4.1 在 Xcode Organizer
选择刚刚 Archive 的版本，点击 Distribute App。
选择 App Store Connect → Upload。
按提示选择签名证书，继续下一步。
上传完成后，App 会出现在 App Store Connect 的 TestFlight 页面。
4.2 TestFlight 测试
进入 App Store Connect，选择你的 App。
在 TestFlight 标签页下，添加测试人员（可用邮箱邀请）。
通过 TestFlight App 安装测试。
```

### Integration test
```
flutter test integration_test/deck_review_flow_test.dart
```

## CI Release preparation

### 1. 生成 iOS 证书和 Provisioning Profile

#### 1.1 导出 p12 证书
在 Xcode 或 Apple Developer 网站下载你的 iOS Distribution 证书（.cer），并用钥匙串导出为 p12：

1. 打开“钥匙串访问”，找到你的 iOS Distribution 证书。
2. 右键导出，选择 .p12 格式，设置导出密码。

#### 1.2 导出 Provisioning Profile
在 Apple Developer 网站下载你的 App 的 Distribution Provisioning Profile（.mobileprovision）。

#### 1.3 Base64 编码
将证书和 profile 转为 base64 以便上传到 GitHub Secrets：

```sh
base64 -i path/to/your_certificate.p12 > certificate.p12.b64
base64 -i path/to/your_profile.mobileprovision > profile.mobileprovision.b64
```

### 2. 生成 ExportOptions.plist

1. 在 Xcode 中，使用“归档”功能（Product > Archive），导出 IPA 时会生成 ExportOptions.plist。
2. 将其复制到 `ios/ExportOptions.plist`，并根据需要调整（如 `signingStyle` 设为 `manual`，配置 `provisioningProfiles`）。

### 3. 配置 GitHub Secrets

在你的 GitHub 仓库页面，依次进入：

- Settings → Secrets and variables → Actions → New repository secret

添加如下 secrets（内容为上面 base64 文件的内容，或相关密码）：

- `IOS_BUILD_CERTIFICATE_BASE64`：certificate.p12.b64 的内容
- `IOS_BUILD_CERTIFICATE_PASSWORD`：p12 导出时设置的密码
- `IOS_MOBILE_PROVISIONING_PROFILE_BASE64`：profile.mobileprovision.b64 的内容
- `IOS_GITHUB_KEYCHAIN_PASSWORD`：任意字符串（如 `randompassword123`）

### 4. Workflow 示例

见 `.github/workflows/ios-release.yml`，核心步骤如下：

```yaml
- uses: cedvdb/action-flutter-build-ios@v1
  with:
    build-cmd: flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
    certificate-base64: ${{ secrets.IOS_BUILD_CERTIFICATE_BASE64 }}
    certificate-password: ${{ secrets.IOS_BUILD_CERTIFICATE_PASSWORD }}
    provisioning-profile-base64: ${{ secrets.IOS_MOBILE_PROVISIONING_PROFILE_BASE64 }}
    keychain-password: ${{ secrets.IOS_GITHUB_KEYCHAIN_PASSWORD }}
```

---

如需自动上传到 TestFlight，可参考 fastlane 或 appleboy/app-store-release-action 的用法。
