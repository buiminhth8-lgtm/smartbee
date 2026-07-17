# Smartbee MediaMTX 开发服务器

本目录提供本地和局域网开发用的 MediaMTX 配置。它允许匿名发布和读取，只适合可信开发网络。

## 启动

```bash
cd server
docker compose up -d
docker compose logs -f
```

## 停止

```bash
docker compose down
```

## 默认端口

- RTSP：`8554`
- RTMP：`1935`
- HLS / LL-HLS：`8888`
- WebRTC / WHIP：`8889`
- WebRTC UDP：`8189/udp`
- API：`9997`
- Metrics：`9998`

## 开发地址示例

- WHIP 发布：`http://127.0.0.1:8889/smartbee/whip`
- RTSP 播放：`rtsp://127.0.0.1:8554/smartbee`
- RTMP 播放：`rtmp://127.0.0.1:1935/smartbee`
- HLS 播放：`http://127.0.0.1:8888/smartbee/index.m3u8`
- WebRTC 播放：`http://127.0.0.1:8889/smartbee`

## 安全提示

当前配置仅适用于局域网开发环境。生产环境必须配置鉴权、HTTPS、RTMPS、网络访问控制和 TURN，不能直接暴露匿名发布入口。
