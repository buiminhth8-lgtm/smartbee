# Smartbee

Smartbee 是一个 Flutter 跨平台应用，当前包含三个主要能力：

- 地图页面：基于 `flutter_map` 展示 OpenStreetMap 地图，支持点击移动标记、显示经纬度和缩放控制。
- 实时推流：基于 `flutter_webrtc` 采集摄像头或屏幕，通过 WebRTC WHIP 发布到 MediaMTX，由服务器转换输出 RTSP、RTMP、HLS/LL-HLS 和 WebRTC。
- 中文小说写作：管理小说作品、分卷和章节，支持中文正文编辑、800ms 自动保存、手动保存、备份恢复和本地持久化。

## 架构

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

第一阶段客户端只实现 WHIP 推流。RTMP/RTSP 原生直推保留接口，但不会伪装成可用功能；需要直推时应通过独立 Publisher Adapter 扩展。

## 支持平台

项目包含 Android、iOS、Web、Windows、macOS、Linux 工程。当前开发环境为 Windows，本次已完成 Android debug APK、Windows 和 Web 的编译验证；Android 真机录屏授权、Windows 来源选择和浏览器授权仍需要人工点击验收。iOS、macOS、Linux 需要在对应系统中验证。

| 功能 | Android | Windows | Web | Linux | macOS | iOS |
| --- | --- | --- | --- | --- | --- | --- |
| 摄像头预览 | APK构建通过，待真机验证 | 构建通过，待人工验证 | 构建通过，待浏览器验证 | 待验证 | 待验证 | 待验证 |
| 屏幕预览 | APK构建通过，待真机验证 | 构建通过，待人工验证 | 构建通过，待浏览器验证 | 待验证 | 待验证 | 待验证 |
| 屏幕音频 | 第一阶段关闭 | 第一阶段关闭 | 第一阶段关闭 | 待验证 | 待验证 | 待验证 |
| WHIP推流 | APK构建通过，待MediaMTX验证 | 构建通过，待MediaMTX验证 | 构建通过，待MediaMTX验证 | 待验证 | 待验证 | 待验证 |
| RTSP输出 | 服务器提供 | 服务器提供 | 服务器提供 | 服务器提供 | 服务器提供 | 服务器提供 |
| RTMP输出 | 服务器提供 | 服务器提供 | 服务器提供 | 服务器提供 | 服务器提供 | 服务器提供 |
| HLS输出 | 服务器提供 | 服务器提供 | 服务器提供 | 服务器提供 | 服务器提供 | 服务器提供 |

只有经过真实设备或目标平台测试后，才能把“待验证”改成“支持”。

## 运行环境

- Flutter 3.44.6 stable
- Dart 3.12.2
- `flutter_map` 8.3.1
- `flutter_webrtc` 1.5.2
- `http` 1.x
- `shared_preferences` 2.x
- `uuid` 4.x

## 启动应用

```bash
flutter pub get
flutter run
```

指定平台：

```bash
flutter run -d chrome
flutter run -d windows
flutter run -d android
```

## 地图功能

地图页面保留原有行为：

- 默认中心点为北京坐标。
- 点击地图可移动红色标记。
- 左上角显示标记经纬度。
- 右下角提供放大、缩小、回到标记位置按钮。

OpenStreetMap 公共瓦片服务不适合高流量生产环境。生产环境应确认瓦片服务政策，或使用自建/商业瓦片服务。

### Windows 地图瓦片网络诊断

Windows 浏览器可访问 OSM 瓦片，并不代表 Flutter/Dart 原生网络栈也会自动走同一条代理或 PAC 路径。地图模块为瓦片请求单独创建 `HttpClient`，不会设置全局 `HttpOverrides.global`，也不会影响 WHIP 访问 `http://127.0.0.1:8889/smartbee/whip`。

可用配置：

```powershell
flutter run -d windows `
  --dart-define=MAP_HTTP_PROXY=127.0.0.1:7890
```

也可以显式切换地图瓦片源或协议：

```powershell
flutter run -d windows `
  --dart-define=MAP_TILE_URL_TEMPLATE=https://tile.openstreetmap.org/{z}/{x}/{y}.png
```

未设置 `MAP_HTTP_PROXY` 时，地图专用 client 会读取进程环境变量 `HTTPS_PROXY`、`HTTP_PROXY` 和 `NO_PROXY`。Dart `HttpClient` 的 `findProxy` 只支持 HTTP CONNECT 代理格式 `host:port` 或 `http://host:port`；不要填写 SOCKS/PAC 地址。若浏览器依赖 SOCKS/PAC，请改用可提供 HTTP 代理端口的本地代理，或配置可直连的瓦片源。

网络探针：

```powershell
dart run tool/osm_network_probe.dart

dart run "-DMAP_HTTP_PROXY=127.0.0.1:7890" tool/osm_network_probe.dart

dart run "-DMAP_TILE_URL_TEMPLATE=https://tile.openstreetmap.org/{z}/{x}/{y}.png" tool/osm_network_probe.dart
```

探针成功时应看到 `status=200` 且 `bytes>0`。如果无代理时超时、配置 HTTP 代理后成功，说明浏览器使用了代理网络路径，而 Dart 原生直连路径不可达。

## 中文小说写作

页面入口：底部导航或桌面宽屏 `NavigationRail` 中的“小说写作”。

功能：

- 创建和管理小说作品、分卷和章节。
- 编辑章节标题和中文正文。
- 停止输入约 800ms 后自动保存，也可使用保存按钮或 `Ctrl+S` / `Meta+S` 立即保存。
- 自动保存使用 revision 串行化，旧保存任务不会覆盖新正文。
- Windows、Linux、Android、iOS、macOS 使用 `<ApplicationDocuments>/smartbee/novels/` 文件目录，每个章节独立 JSON 文件保存。
- Web 使用 `shared_preferences`，键名为 `novel_writing.index`、`novel_writing.project.<projectId>` 和 `novel_writing.chapter.<projectId>.<chapterId>`，不会复用直播配置键。
- IO 平台写入采用 `.tmp`、`.bak` 原子替换流程；正式文件损坏时会尝试从备份恢复。
- 字数统计使用 Unicode code point 遍历，不统计空格、制表符和换行，标点和 Emoji 当前计入字数。

当前不支持 AI 续写、云同步、富文本、图片、全文搜索、EPUB 和多人协作。

## 实时推流功能

页面入口：底部导航或桌面宽屏 `NavigationRail` 中的“实时推流”。

功能：

- 选择采集来源：摄像头或屏幕。
- 摄像头预览和屏幕预览。
- 服务器地址、端口、流名称、HTTP/HTTPS、Bearer Token 配置。
- 视频分辨率、帧率、视频码率、音频码率配置。
- 打开预览、开始推流、停止推流、切换摄像头、静音、关闭视频、全屏预览。
- 显示 WHIP、RTSP、RTMP、HLS、WebRTC 地址并支持复制。
- 显示推流状态、时长、分辨率、帧率、码率、发送字节、丢包、RTT、编码、ICE 状态等统计。
- 日志只保留最近 200 条，并会脱敏 Bearer Token。

## 屏幕预览

屏幕采集现在由统一 `MediaCaptureService` 调度，按平台分派到 `AndroidScreenCaptureAdapter`、`DesktopScreenCaptureAdapter`、`WebScreenCaptureAdapter`、`AppleScreenCaptureAdapter` 和 `LinuxScreenCaptureAdapter`。Controller 只处理请求、成功、失败、停止和状态更新；平台权限、来源选择和系统停止共享事件由采集层处理。

通用规则：

- `startScreenCapture()` 必须返回真实 `MediaStream`，并且至少包含一条视频轨。
- 失败时不会伪造空流或伪造成功状态。
- 重复打开预览会被 Controller 操作锁拦截。
- 停止采集会显式 `track.stop()` 并 `stream.dispose()`，且可以重复调用。
- 系统停止共享时通过视频轨 `onEnded` 通知 Controller，UI 状态变为已停止。
- 第一阶段屏幕采集统一使用 `audio: false`，避免系统音频和麦克风权限差异阻塞预览。
- 诊断日志使用 `[ScreenCapture] platform=... step=...` 格式，记录阶段、状态、轨道数量和非敏感异常摘要；Token、密码和认证头不会进入日志。

平台差异：

- Android：用户点击后调用 `Helper.requestCapturePermission(fullScreenOnly: true)` 触发系统 MediaProjection 授权，再以最小约束调用 `getDisplayMedia({'video': true, 'audio': false})`。当前不额外引入 `flutter_background` 或自定义前台服务，避免与 `flutter_webrtc 1.5.2` 的 MediaProjection 流程冲突。Android 14+ 如目标设备要求 mediaProjection 前台服务通知，需要结合真实设备日志继续补原生通知链路。
- Windows：先用 `desktopCapturer.getSources()` 枚举整屏和窗口来源，弹出来源选择对话框；用户取消不会崩溃，选择后把真实 `source.id` 写入 `getDisplayMedia()` 的 `deviceId.exact`。
- Web：只使用浏览器 `getDisplayMedia()`，必须由用户点击触发，并要求 HTTPS 或 localhost。
- Linux：依赖 PipeWire、WirePlumber、xdg-desktop-portal 和对应桌面 portal backend，不假设所有桌面环境一致。
- macOS：需要系统“屏幕录制”权限；iOS 需要 ReplayKit/Broadcast Extension，当前未伪造已完成。

## MediaMTX 开发服务器

项目内置开发服务器配置：

```text
server/
├── docker-compose.yml
├── mediamtx.yml
└── README.md
```

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

开发配置允许匿名发布和读取，仅适用于局域网开发环境。生产环境必须配置鉴权、HTTPS、RTMPS、网络访问控制和 TURN。

## 权限说明

### Android

已声明：

- `INTERNET`
- `CAMERA`
- `RECORD_AUDIO`
- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_MEDIA_PROJECTION`
- `POST_NOTIFICATIONS`

屏幕共享必须经过系统 MediaProjection 授权。当前流程依赖 `flutter_webrtc 1.5.2` 的授权能力，不绕过系统授权页，不静默录屏。Android 版本要求前台服务时，需要由插件或后续原生层启动 mediaProjection 类型前台服务并显示持续通知；如增加自定义 Service，必须声明 `android:foregroundServiceType="mediaProjection"`。

### iOS

已配置：

- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`

iOS 屏幕共享如需 Broadcast Extension，应单独创建并真机验证。当前主工程不伪造 Broadcast Extension 已完成。

### macOS

已配置：

- 摄像头使用说明
- 麦克风使用说明
- 屏幕录制使用说明
- Camera entitlement
- Audio Input entitlement
- Network Client entitlement

屏幕录制仍需用户在系统设置中授权。

### Windows

通过 `flutter_webrtc` 的 `desktopCapturer.getSources()` 枚举系统窗口和屏幕来源，应用内弹窗由用户手动选择。用户取消选择时回到空闲状态，不清空仍有效的预览，不应崩溃。

### Linux

优先兼容 Wayland、X11、PipeWire、xdg-desktop-portal。目标环境通常需要安装：

```bash
pipewire
wireplumber
xdg-desktop-portal
```

还需要安装与桌面环境匹配的 portal backend，例如 GNOME 或 KDE 对应实现。不同 Linux 桌面环境能力不完全一致，需要逐一验证。

### Web

Web 端只使用 WebRTC/WHIP：

- 摄像头和麦克风需要 HTTPS 或 localhost。
- `getDisplayMedia()` 必须由用户点击触发。
- 浏览器不能使用原生 FFmpeg、RTMP 或 RTSP Socket 推流。
- 不使用 `dart:io`。
- 页面刷新或关闭时需要浏览器释放 track；应用内停止按钮会主动释放当前流。

## 测试

```bash
dart format .
flutter analyze
flutter test
```

本次验证结果：

- `flutter analyze` 通过。
- `flutter test` 通过，28 个测试通过。
- 测试覆盖录屏预览成功、空视频轨失败、用户取消、权限拒绝、重复点击拦截、系统停止共享、Renderer 初始化/绑定/释放、平台适配隔离、地图页面不回归。

当前测试覆盖：

- 地图页面可以打开。
- 推流页面可以打开。
- 默认配置正确。
- 非法 Host、端口、流名称会被拒绝。
- 输出地址构造正确。
- 摄像头和屏幕预览状态转换。
- 开始推流成功与失败路径。
- 停止操作幂等。
- 用户停止后不会自动重连。
- Token 不进入日志。
- 不支持协议返回明确错误。
- 页面销毁时释放预览 renderer。
- 默认地图功能不被破坏。

## 构建

当前 Windows 环境可验证：

```bash
flutter build apk --debug --no-pub
flutter build web --no-pub
flutter build windows --no-pub
```

本次验证结果：

- Android debug APK 构建通过：`build\app\outputs\flutter-apk\app-debug.apk`。
- Windows Release 构建通过：`build\windows\x64\runner\Release\smartbee.exe`。
- Web 构建通过：`build\web`。

Android 构建在 Windows 跨盘符环境中关闭了 Kotlin 增量编译：`android/gradle.properties` 中设置 `kotlin.incremental=false`。原因是 Flutter 插件位于 `C:\Users\...\Pub\Cache`，工程位于 `D:\project\smartbee` 时，Kotlin incremental cache 可能因不同磁盘根路径失败。

需要在对应系统验证：

```bash
flutter build linux
flutter build macos
flutter build ios --no-codesign
```

不能在 Windows 环境声称 iOS、macOS 或 Linux 构建通过。

## 生产环境安全要求

- MediaMTX 必须启用发布鉴权。
- 生产 WHIP 地址必须使用 HTTPS。
- 外网 WebRTC 应配置 TURN。
- RTMP 应优先使用 RTMPS 或内网传输。
- Bearer Token 不应保存到普通 preferences。
- 不应把完整认证请求头、Token、密码或隐私信息写入日志。

## 已知限制

- 第一阶段只实现 WHIP 推流；RTMP/RTSP 原生直推仅保留扩展接口。
- HLS 由 MediaMTX 服务器生成，客户端不生成 HLS。
- 不实现多路码流、Simulcast 控制 UI、SVC、美颜、滤镜、背景替换、画中画混流。
- H.264 会在 SDP 中优先协商；平台不支持时允许回退 VP8。
- `flutter_webrtc 1.5.2` 可设置 `maxBitrate`、`maxFramerate`、`scaleResolutionDownBy` 和 `degradationPreference`，但更细粒度硬件编码选择未实现。
- Android 真机 MediaProjection 通知链路、Windows 来源选择实际画面、Web 浏览器授权、iOS Broadcast Extension、Linux portal 差异需要目标平台继续验证。

## 第二阶段扩展点

保留或建议新增：

- `NativeRtmpPublisher`
- `NativeRtspPublisher`
- `SrtPublisher`
- `LocalRecordingService`
- `PictureInPictureComposer`
- `CameraAndScreenMixer`
- `HardwareEncoderSelector`
- `AdaptiveBitrateController`

未来原生直推建议：

- Android：MediaCodec + libavformat/GStreamer
- iOS/macOS：VideoToolbox + AVFoundation
- Windows：Media Foundation / FFmpeg / GStreamer
- Linux：PipeWire + VAAPI + GStreamer/FFmpeg
- Web：继续使用 WebRTC，不实现原生 RTMP/RTSP
