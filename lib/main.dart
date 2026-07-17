import 'package:flutter/material.dart';

import 'features/map/map_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MapDemoApp());
}

class MapDemoApp extends StatelessWidget {
  const MapDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '跨平台地图示例',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const MapPage(),
    );
  }
}