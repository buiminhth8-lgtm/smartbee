import 'dart:async';

import 'package:flutter/material.dart';

import '../features/live_stream/application/live_stream_controller.dart';
import '../features/live_stream/infrastructure/capture/webrtc_media_capture_service.dart';
import '../features/live_stream/infrastructure/publisher/whip_publisher.dart';
import '../features/live_stream/infrastructure/storage/stream_config_storage.dart';
import '../features/live_stream/presentation/live_stream_page.dart';
import '../features/map/map_page.dart';
import '../features/novel_writing/application/novel_writing_controller.dart';
import '../features/novel_writing/infrastructure/local_novel_repository.dart';
import '../features/novel_writing/infrastructure/storage/novel_storage.dart';
import '../features/novel_writing/presentation/novel_writing_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.liveStreamController,
    this.novelWritingController,
  });

  final LiveStreamController? liveStreamController;
  final NovelWritingController? novelWritingController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final LiveStreamController _liveStreamController;
  late final NovelWritingController _novelWritingController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _liveStreamController =
        widget.liveStreamController ??
        LiveStreamController(
          captureService: WebRtcMediaCaptureService(),
          publisherFactory: StreamPublisherFactory.defaults(),
          storage: StreamConfigStorage(),
        );
    _novelWritingController =
        widget.novelWritingController ??
        NovelWritingController(
          repository: LocalNovelRepository(
            storage: NovelStorageFactory.create(),
          ),
        );
    _liveStreamController.loadSavedConfig();
    unawaited(_novelWritingController.loadLibrary());
  }

  @override
  void dispose() {
    _liveStreamController.dispose();
    unawaited(_novelWritingController.close());
    _novelWritingController.dispose();
    super.dispose();
  }

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const MapPage(),
      LiveStreamPage(controller: _liveStreamController),
      NovelWritingPage(controller: _novelWritingController),
      const _SettingsPage(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 840;
        if (useRail) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectPage,
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.map_outlined),
                      selectedIcon: Icon(Icons.map),
                      label: Text('地图'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.sensors_outlined),
                      selectedIcon: Icon(Icons.sensors),
                      label: Text('实时推流'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.menu_book_outlined),
                      selectedIcon: Icon(Icons.menu_book),
                      label: Text('小说写作'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('设置'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(index: _selectedIndex, children: pages),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(index: _selectedIndex, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectPage,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: '地图',
              ),
              NavigationDestination(
                icon: Icon(Icons.sensors_outlined),
                selectedIcon: Icon(Icons.sensors),
                label: '实时推流',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: '小说写作',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: const Center(child: Text('设置项将在后续版本扩展')),
    );
  }
}
