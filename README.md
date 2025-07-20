# open_anki

```
flutter_rust_bridge_codegen generate --watch
```

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