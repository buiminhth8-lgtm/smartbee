import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'infrastructure/map_tile_http_client.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const double _minZoom = 2;
  static const double _maxZoom = 19;

  final MapController _mapController = MapController();
  final MapTileErrorLogger _tileErrorLogger = MapTileErrorLogger();
  late final MapTileHttpClientBundle _mapTileNetwork;
  String? _mapTileErrorMessage;

  // 示例位置，可替换为你的业务坐标。
  LatLng _markerPosition = const LatLng(39.9042, 116.4074);

  @override
  void initState() {
    super.initState();
    _mapTileNetwork = _createMapTileNetwork();
    debugPrint(
      '[MapTile] step=page-init '
      'proxy=${_mapTileNetwork.proxyDescription}',
    );
  }

  MapTileHttpClientBundle _createMapTileNetwork() {
    try {
      return MapTileHttpClientFactory.create();
    } on ArgumentError catch (error) {
      debugPrint(
        '[MapTile] step=explicit-proxy-invalid '
        'errorType=${error.runtimeType} '
        'error=$error',
      );
      _mapTileErrorMessage = '地图代理配置无效，已回退到环境变量或直连。';
      return MapTileHttpClientFactory.create(explicitProxy: '');
    }
  }

  void _changeZoom(double delta) {
    final camera = _mapController.camera;

    final newZoom = (camera.zoom + delta).clamp(_minZoom, _maxZoom).toDouble();

    _mapController.move(camera.center, newZoom);
  }

  void _resetMap() {
    _mapController.move(_markerPosition, 12);
  }

  void _handleTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    _tileErrorLogger.log(error, tile: tile.coordinates);
    if (!mounted || _mapTileErrorMessage != null) {
      return;
    }

    setState(() {
      _mapTileErrorMessage = '地图瓦片加载失败，请检查网络或地图代理配置。';
    });
  }

  @override
  void dispose() {
    debugPrint('[MapTile] step=page-dispose');
    _mapTileNetwork.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('地图示例')),
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
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileProvider: _mapTileNetwork.tileProvider,

                userAgentPackageName: 'com.example.smartbee',

                maxNativeZoom: 19,
                panBuffer: 0,
                errorTileCallback: _handleTileError,
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
                  TextSourceAttribution('OpenStreetMap contributors'),
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

          if (_mapTileErrorMessage != null)
            Positioned(
              left: 16,
              bottom: 24,
              right: 96,
              child: Card(
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(
                    '$_mapTileErrorMessage\n'
                    '代理模式：${_mapTileNetwork.proxyDescription}\n'
                    '地图源：OpenStreetMap',
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
