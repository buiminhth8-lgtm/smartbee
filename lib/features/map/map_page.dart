import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const double _minZoom = 2;
  static const double _maxZoom = 19;

  final MapController _mapController = MapController();

  // 示例位置，可替换为你的业务坐标。
  LatLng _markerPosition = const LatLng(39.9042, 116.4074);

  void _changeZoom(double delta) {
    final camera = _mapController.camera;

    final newZoom = (camera.zoom + delta)
        .clamp(_minZoom, _maxZoom)
        .toDouble();

    _mapController.move(camera.center, newZoom);
  }

  void _resetMap() {
    _mapController.move(_markerPosition, 12);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地图示例'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _markerPosition,
              initialZoom: 12,
              minZoom: _minZoom,
              maxZoom: _maxZoom,

              // 点击地图后移动标记。
              onTap: (tapPosition, point) {
                setState(() {
                  _markerPosition = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                // 必须替换为你的真实 Android applicationId。
                // 同时用于向地图瓦片服务器标识应用。
                userAgentPackageName: 'com.example.flutter_map_demo',

                maxNativeZoom: 19,
              ),

              MarkerLayer(
                markers: [
                  Marker(
                    point: _markerPosition,
                    width: 56,
                    height: 56,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_pin,
                      size: 48,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),

              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                  ),
                ],
              ),
            ],
          ),

          // 左上角显示当前标记经纬度。
          Positioned(
            top: 16,
            left: 16,
            right: 100,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  '经度：${_markerPosition.longitude.toStringAsFixed(6)}\n'
                      '纬度：${_markerPosition.latitude.toStringAsFixed(6)}',
                ),
              ),
            ),
          ),

          // 右侧地图控制按钮，方便桌面端使用。
          Positioned(
            right: 16,
            bottom: 24,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  tooltip: '放大',
                  onPressed: () => _changeZoom(1),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  tooltip: '缩小',
                  onPressed: () => _changeZoom(-1),
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'reset_map',
                  tooltip: '回到标记位置',
                  onPressed: _resetMap,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}