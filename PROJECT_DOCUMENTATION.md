# smartbee 项目文档

生成日期：2026-07-17

## 1. 项目概览

`smartbee` 是一个 Flutter 跨平台应用项目，当前核心功能是一个地图示例页面：

- 使用 `flutter_map` 渲染 OpenStreetMap 瓦片地图。
- 默认定位到北京坐标：`39.9042, 116.4074`。
- 点击地图可移动标记点。
- 左上角显示当前标记点经纬度。
- 右下角提供放大、缩小、回到标记位置三个地图控制按钮。

当前项目仍保留较多 Flutter 默认模板内容，业务代码规模较小，主要代码集中在 `lib/main.dart` 和 `lib/features/map/map_page.dart`。

## 2. 技术栈与环境

### Flutter / Dart

- Flutter：`3.44.6 stable`
- Dart：`3.12.2`
- SDK 约束：`^3.12.2`
- DevTools：`2.57.0`

### 主要依赖

| 依赖 | 版本约束 | 用途 |
| --- | --- | --- |
| `flutter` | SDK | Flutter 应用框架 |
| `flutter_map` | `^8.3.1` | 地图组件 |
| `latlong2` | `^0.10.1` | 经纬度数据结构与地理坐标工具 |
| `cupertino_icons` | `^1.0.8` | iOS 风格图标 |
| `flutter_lints` | `^6.0.0` | 推荐 lint 规则 |

`pubspec.lock` 当前锁定的关键版本：

- `flutter_map`：`8.3.1`
- `latlong2`：`0.10.1`
- `flutter_lints`：`6.0.0`

## 3. 目录结构

```text
smartbee/
├── android/                 # Android 平台工程
├── ios/                     # iOS 平台工程
├── lib/                     # Flutter/Dart 主代码
│   ├── main.dart            # 应用入口，加载 MapDemoApp
│   └── features/
│       └── map/
│           └── map_page.dart # 地图页面
├── linux/                   # Linux 桌面端工程
├── macos/                   # macOS 桌面端工程
├── test/                    # Flutter 测试
│   └── widget_test.dart     # 当前仍是默认 Counter 测试，需要更新
├── web/                     # Web 端工程
├── windows/                 # Windows 桌面端工程
├── analysis_options.yaml    # Dart 静态分析规则
├── pubspec.yaml             # Flutter 项目配置与依赖声明
├── pubspec.lock             # 依赖锁定文件
└── README.md                # Flutter 默认 README
```

当前项目包含 Android、iOS、Web、Windows、macOS、Linux 六类平台工程文件。

## 4. 核心模块说明

### 4.1 应用入口：`lib/main.dart`

入口函数：

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MapDemoApp());
}
```

`MapDemoApp` 是根组件，负责创建 `MaterialApp`：

- 应用标题：`跨平台地图示例`
- 关闭 debug 横幅
- 使用 Material 3
- 主题种子色：蓝色
- 首页：`MapPage`

### 4.2 地图页面：`lib/features/map/map_page.dart`

`MapPage` 是一个 `StatefulWidget`，内部维护当前标记点位置：

```dart
LatLng _markerPosition = const LatLng(39.9042, 116.4074);
```

地图能力：

- `FlutterMap` 负责地图渲染。
- `MapController` 负责缩放和移动地图视角。
- `MapOptions` 设置初始中心点、初始缩放级别、最小/最大缩放级别。
- `onTap` 处理地图点击，将标记移动到点击位置。
- `TileLayer` 使用 OpenStreetMap 公共瓦片服务。
- `MarkerLayer` 显示红色定位图标。
- `RichAttributionWidget` 显示 OpenStreetMap 贡献者归属信息。

交互控件：

- `+`：地图放大一级。
- `-`：地图缩小一级。
- 定位按钮：回到当前标记点，缩放级别重置为 `12`。

缩放范围：

```dart
static const double _minZoom = 2;
static const double _maxZoom = 19;
```

## 5. 平台配置

### Android

配置文件：

- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`

当前 Android 配置：

- `namespace`：`com.example.smartbee`
- `applicationId`：`com.example.smartbee`
- Java 版本：17
- Kotlin JVM target：17
- 已声明网络权限：

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

注意：`map_page.dart` 中 `TileLayer.userAgentPackageName` 当前是：

```dart
userAgentPackageName: 'com.example.flutter_map_demo'
```

这与 Android 的真实 `applicationId` 不一致，后续建议改为：

```dart
userAgentPackageName: 'com.example.smartbee'
```

### iOS

配置文件：

- `ios/Runner/Info.plist`

当前显示名：

- `CFBundleDisplayName`：`Smartbee`
- `CFBundleName`：`smartbee`

### Web

配置文件：

- `web/manifest.json`

当前 Web 应用信息：

- `name`：`smartbee`
- `short_name`：`smartbee`
- `display`：`standalone`
- `orientation`：`portrait-primary`
- `description`：仍是 Flutter 模板描述：`A new Flutter project.`

## 6. 本地运行

进入项目目录：

```powershell
cd D:\project\smartbee
```

获取依赖：

```powershell
flutter pub get
```

运行应用：

```powershell
flutter run
```

指定平台运行示例：

```powershell
flutter run -d chrome
flutter run -d windows
flutter run -d android
```

可查看可用设备：

```powershell
flutter devices
```

## 7. 构建命令

Web 构建：

```powershell
flutter build web
```

Android APK 构建：

```powershell
flutter build apk
```

Windows 构建：

```powershell
flutter build windows
```

iOS 构建需要在 macOS 和 Xcode 环境中执行：

```bash
flutter build ios
```

## 8. 质量检查

本次读取项目时执行了以下检查。

### 静态分析

命令：

```powershell
flutter analyze
```

结果：

```text
No issues found.
```

### 单元/组件测试

命令：

```powershell
flutter test
```

结果：失败。

失败原因：

- `test/widget_test.dart` 仍是 Flutter 默认 Counter 示例测试。
- 当前应用已经改为地图页面，不再存在文本 `0` 和 `1` 的计数器界面。
- 测试断言与实际 UI 不匹配。

建议将测试改为地图页面 smoke test，例如验证：

- 应用能正常加载 `MapDemoApp`。
- 页面标题显示 `地图示例`。
- 存在放大、缩小、回到标记位置三个按钮。
- 点击地图后经纬度文本发生变化。

## 9. 已知问题与待办

1. 更新地图瓦片请求标识  
   将 `TileLayer.userAgentPackageName` 从 `com.example.flutter_map_demo` 改为真实包名 `com.example.smartbee`。

2. 更新测试文件  
   `test/widget_test.dart` 仍是默认 Counter 测试，当前必然失败。需要改成地图页面相关测试。

3. 更新 README  
   `README.md` 仍是 Flutter 默认内容，建议改成项目简介、运行方式、功能说明和维护说明。

4. 更新 Web manifest 描述  
   `web/manifest.json` 中 `description` 仍是 `A new Flutter project.`，建议替换为真实项目描述。

5. 确认 OpenStreetMap 瓦片服务使用策略  
   当前使用 `https://tile.openstreetmap.org/{z}/{x}/{y}.png`。生产环境应确认 OpenStreetMap 公共瓦片服务是否适合项目流量；如有较大访问量，建议使用自建瓦片服务或商业地图瓦片服务。

6. 补充业务命名  
   当前类名仍是 `MapDemoApp`，如果项目已经从示例进入正式开发，建议调整为更贴近产品语义的命名。

## 10. 推荐下一步

优先级建议：

1. 修复 `userAgentPackageName` 与 Android `applicationId` 不一致的问题。
2. 替换默认测试，恢复 `flutter test` 通过。
3. 更新 `README.md` 和 Web manifest 描述。
4. 根据真实业务需求继续拆分地图功能，例如定位、搜索、业务标记点、路线规划、离线缓存等。
5. 如果准备发布 Android，补充正式签名配置，避免继续使用 debug signing。

## 11. 当前项目状态摘要

- 项目类型：Flutter 跨平台应用。
- 当前主要功能：地图示例。
- 主要页面数量：1 个。
- 静态分析：通过。
- 自动测试：失败，原因是测试文件未随业务页面更新。
- Git 状态：当前目录未检测到 `.git` 仓库。
- 文档状态：已新增本项目文档。
