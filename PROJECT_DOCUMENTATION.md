# smartbee 项目文档

生成日期：2026-07-17

## 项目概览

`smartbee` 是一个 Flutter 跨平台应用，当前包含：

- 地图模块：基于 `flutter_map` 展示 OpenStreetMap 地图，支持点击移动标记、显示经纬度和缩放控制。
- 实时推流模块：基于 `flutter_webrtc` 采集摄像头或屏幕，通过 WHIP 发布到 MediaMTX，由服务器转换输出 RTSP、RTMP、HLS/LL-HLS 和 WebRTC。

第一阶段客户端统一使用 WebRTC + WHIP，不实现六个平台各自的 FFmpeg RTMP/RTSP/HLS 原生直推。RTMP/RTSP 已保留扩展接口，但当前会明确返回未实现错误。

## 当前入口与导航

- 应用入口：`lib/main.dart`
- 根组件：`SmartbeeApp`
- 导航壳：`AppShell`
- 页面：
  - 地图
  - 实时推流
  - 设置

移动端和窄屏使用底部导航，桌面宽屏使用 `NavigationRail`。页面使用 `IndexedStack` 保持状态，切换到地图页不会释放推流控制器。

## 核心目录

```text
lib/
├── app/
│   ├── app_shell.dart
│   └── smartbee_app.dart
├── features/
│   ├── map/
│   │   └── map_page.dart
│   └── live_stream/
│       ├── domain/
│       ├── application/
│       ├── infrastructure/
│       └── presentation/
server/
├── docker-compose.yml
├── mediamtx.yml
└── README.md
test/
├── app_shell_test.dart
├── widget_test.dart
└── features/live_stream/
```

## 实时推流架构

```text
Camera / Screen Capture
        ↓
flutter_webrtc MediaStream
        ↓
WHIP Publisher
        ↓
MediaMTX Server
        ├── RTSP
        ├── RTMP
        ├── HLS / LL-HLS
        └── WebRTC
```

## 主要实现

- `MediaCaptureService`：采集抽象。
- `WebRtcMediaCaptureService`：基于 `navigator.mediaDevices.getUserMedia()` 和 `getDisplayMedia()`。
- `StreamPublisher`：发布器抽象。
- `WhipPublisher`：真实 WHIP 发布实现。
- `RtmpPublisher` / `RtspPublisher`：保留接口，当前明确返回未实现。
- `LiveStreamController`：基于 `ChangeNotifier` 管理状态、预览、推流、重连、日志和统计。
- `StreamConfigStorage`：使用 `shared_preferences` 保存非敏感配置，默认不保存 Token。

## MediaMTX 开发环境

启动：

```bash
cd server
docker compose up -d
docker compose logs -f
```

停止：

```bash
docker compose down
```

默认地址：

- WHIP：`http://127.0.0.1:8889/smartbee/whip`
- RTSP：`rtsp://127.0.0.1:8554/smartbee`
- RTMP：`rtmp://127.0.0.1:1935/smartbee`
- HLS：`http://127.0.0.1:8888/smartbee/index.m3u8`
- WebRTC：`http://127.0.0.1:8889/smartbee`

## 权限配置

- Android：已添加 `INTERNET`、`CAMERA`、`RECORD_AUDIO`、`FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_MEDIA_PROJECTION`、`POST_NOTIFICATIONS`。
- iOS：已添加摄像头和麦克风使用说明。
- macOS：已添加摄像头、麦克风、屏幕录制说明，以及 camera、audio input、network client entitlements。
- Web：仅使用 WebRTC/WHIP，不依赖 `dart:io`。
- Linux：README 中记录 PipeWire、wireplumber、xdg-desktop-portal 和 portal backend 要求。

## 验证状态

已执行并通过：

```bash
dart format .
flutter analyze
flutter test
flutter build apk --debug --no-pub
flutter build web --no-pub
flutter build windows --no-pub
```

Android debug APK、Windows Release 和 Web 构建均已通过。Windows 跨盘符环境中关闭了 Kotlin 增量编译，避免 Flutter 插件位于 `C:\Users\...\Pub\Cache` 而工程位于 `D:\project\smartbee` 时触发 Kotlin incremental cache 不同根路径错误。

当前 Windows 环境不能真实验证：

- `flutter build linux`
- `flutter build macos`
- `flutter build ios --no-codesign`

## 已知限制

- WHIP 已实现，RTMP/RTSP 原生直推未实现。
- HLS 由 MediaMTX 生成。
- iOS Broadcast Extension 未创建。
- Android MediaProjection 授权、前台服务通知链路需目标设备继续验证。
- Windows 来源选择后的真实画面预览需人工点击验证。
- Linux 屏幕共享依赖桌面环境和 portal 实现。
- 摄像头/屏幕真实采集与 WHIP 推流需要在目标设备和 MediaMTX 服务上人工验收。
