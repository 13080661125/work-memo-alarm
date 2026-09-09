# 02 · 打包 APK（安卓）与 IPA（苹果）完整教程

---

# 第一部分：Android 打包 APK / AAB

## 1. 修改应用信息

### 1.1 版本号
`pubspec.yaml`：
```yaml
version: 1.0.0+1      # 1.0.0 是版本名，+1 是构建号（versionCode），每次上架必须 +1
```

### 1.2 应用名与图标
- **应用名**：`android/app/src/main/AndroidManifest.xml` 中的 `android:label="工作备忘录"`
- **图标**：替换 `android/app/src/main/res/mipmap-*/ic_launcher.png`
  （推荐用 Android Studio 的 **Image Asset Studio** 一键生成各分辨率）

### 1.3 包名（上架后不可更改，务必先定好）
`android/app/build.gradle`：
```groovy
defaultConfig {
    applicationId = "com.example.work_memo_alarm"   // ← 改成你自己的
}
```

---

## 2. 生成签名密钥（只需做一次）

```bash
# Windows（在 JDK 的 bin 目录下执行，或已配置 JAVA_HOME）
keytool -genkey -v -keystore D:\keys\work-memo.jks ^
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 ^
  -alias memokey

# macOS / Linux
keytool -genkey -v -keystore ~/keys/work-memo.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias memokey
```
按提示输入密钥库密码、姓名、组织等信息，**密码务必妥善保存，丢失将无法更新应用**。

---

## 3. 配置签名（已在本项目中预埋逻辑）

在项目根目录创建 `android/key.properties`（**不要提交到 git**）：
```properties
storeFile=D:/keys/work-memo.jks        # macOS 写 /Users/xxx/keys/work-memo.jks
storePassword=你的密钥库密码
keyAlias=memokey
keyPassword=你的密钥密码
```

本项目 `android/app/build.gradle` 已包含：
```groovy
signingConfigs {
    release {
        def keystorePropertiesFile = rootProject.file("key.properties")
        if (keystorePropertiesFile.exists()) {
            // 读取上面的配置
        }
    }
}
buildTypes {
    release {
        signingConfig = signingConfigs.release.storeFile != null
                ? signingConfigs.release : signingConfigs.debug
    }
}
```
即：**有 key.properties 就打正式签名包，没有就用 debug 签名**（方便先跑通流程）。

同时确认 `.gitignore` 已忽略密钥：
```
*.jks
*.keystore
key.properties
```

---

## 4. 执行打包

```bash
# 4.1 清理旧产物
flutter clean && flutter pub get

# 4.2 单包 APK（兼容性最好，适合直接分发安装）
flutter build apk --release

# 4.3 按 CPU 架构拆分（体积更小，推荐）
flutter build apk --split-per-abi --release

# 4.4 上架 Google Play 用 AAB
flutter build appbundle --release
```

产物位置：

| 命令 | 产物 |
| --- | --- |
| `flutter build apk` | `build/app/outputs/flutter-apk/app-release.apk` |
| `flutter build apk --split-per-abi` | `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`、`app-arm64-v8a-release.apk`、`app-x86_64-release.apk` |
| `flutter build appbundle` | `build/app/outputs/bundle/release/app-release.aab` |

### 安装验证
```bash
flutter install                      # 安装到已连接设备
# 或
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 减小体积（可选）
```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```

---

## 5. 混淆注意事项（重要）

本项目**默认关闭混淆**（`minifyEnabled false`），因为：
1. 反射 / JSON 序列化相关代码在开启混淆后容易出错；
2. 闹钟依赖大量插件的 Java 类，混淆规则漏配会导致"打包后闹钟不响"。

如需开启，请在 `android/app/proguard-rules.pro` 中加入：
```proguard
# Flutter 基础
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 本地通知（闹钟核心，必须保留）
-keep class com.dexterous.** { *; }
-keep class androidx.core.app.NotificationCompat** { *; }
```
并把 `build.gradle` 中改为 `minifyEnabled true`。

---

# 第二部分：iOS 打包 IPA

> **前置条件**：iOS 打包**必须使用 macOS + Xcode**，Windows 无法完成。
> 没有 Mac 的三种替代方案见本部分第 6 节。

## 1. 准备开发者账号
1. 注册 [Apple Developer](https://developer.apple.com/)（个人/公司 688 元/年）
2. 在 Xcode 中登录：Xcode → Settings → Accounts → 添加 Apple ID

## 2. 配置 Bundle ID 与签名
1. 打开 `ios/Runner.xcworkspace`（**注意不是 .xcodeproj**）
2. 左侧选中 `Runner` → 目标 `Runner` → **Signing & Capabilities**
3. 勾选 **Automatically manage signing**
4. Team 选择你的开发者团队
5. Bundle Identifier 改成唯一值，如 `com.yourcompany.workmemoalarm`

## 3. 修改应用信息
- **应用名**：`ios/Runner/Info.plist` → `CFBundleDisplayName`（已设为"工作备忘录"）
- **版本号**：`pubspec.yaml` 的 `version: 1.0.0+1`
- **图标**：Xcode 中 `Runner/Assets.xcassets/AppIcon.appiconset`（或命令行 `flutter build ipa` 前替换图片）

## 4. 安装依赖
```bash
cd ios
pod install --repo-update      # 首次较慢
cd ..
```

## 5. 打包 IPA（两种方式）

### 方式 A：命令行（推荐，便于 CI）
```bash
# 5.1 生成 xcarchive + IPA（自动处理签名）
flutter build ipa --release

# 指定导出方式（四选一）
flutter build ipa --release --export-method ad-hoc        # 指定设备分发
flutter build ipa --release --export-method app-store     # 上架 App Store
flutter build ipa --release --export-method development   # 开发调试
flutter build ipa --release --export-method enterprise    # 企业内部分发
```
产物：`build/ios/ipa/工作备忘录.ipa`

### 方式 B：Xcode 图形界面
1. `flutter build ios --release`（或直接 Xcode 中 Product → Archive）
2. Xcode → **Product → Archive**
3. 弹出 Organizer → **Distribute App**
4. 依次选择：App Store Connect → Upload → 勾选签名选项 → Upload
5. 上传成功后到 [App Store Connect](https://appstoreconnect.apple.com) 填写资料提交审核

## 6. 没有 Mac 的替代方案
| 方案 | 说明 |
| --- | --- |
| 云 Mac 租赁 | macincloud、MacStadium，按小时计费，远程桌面操作 |
| CI 服务 | **Codemagic**（对 Flutter 支持最好，免费额度够用）、GitHub Actions + macOS runner、Bitrise |
| 个人开发者账号借用 | 用朋友的 Mac 临时打包，不推荐长期方案 |

Codemagic 示例（项目根目录 `codemagic.yaml`）：
```yaml
workflows:
  ios-release:
    name: iOS Release
    instance_type: mac_mini_m2
    scripts:
      - flutter pub get
      - flutter build ipa --release --export-method app-store
    artifacts:
      - build/ios/ipa/*.ipa
```

---

# 第三部分：上架审核注意事项（闹钟类 App 重点）

## Android（Google Play）
1. **USE_EXACT_ALARM 权限**属于受管权限：审核时需在"权限声明"中说明用途为"闹钟应用"，否则可能被拒。
2. **USE_FULL_SCREEN_INTENT**：同样需要在政策声明中说明（本项目用于闹钟全屏提醒）。
3. 若不需要上架，仅内部分发，可忽略上述两条。

## iOS（App Store）
1. 需在 **Info.plist** 说明通知用途；本项目通过 `requestPermissions` 首次弹窗时由用户授权。
2. 若使用了 **Critical Alerts（关键提醒）** 需要向苹果额外申请权限（本项目**未使用**，用的是 `timeSensitive` 时间敏感级别，无需额外申请）。
3. 音频后台播放：本项目**未申请** `UIBackgroundModes = audio`，因此审核无风险；响铃发生在用户点击通知、APP 进入前台之后。
4. 隐私清单：Flutter 3.22+ 生成的 iOS 工程已内置隐私描述，按需补充。

---

# 第四部分：打包前自检清单

- [ ] `flutter clean && flutter pub get` 无报错
- [ ] Android：`key.properties` 已配置，`applicationId` 已改
- [ ] Android：图标、应用名已改
- [ ] Android：真机**退到后台**测试过一次闹钟（重点！）
- [ ] iOS：Xcode 中 4 个 wav 铃声已加入 Copy Bundle Resources
- [ ] iOS：真机测试过通知（**模拟器无法测试通知**）
- [ ] 版本号已递增
