import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/capture_source_type.dart';
import '../../domain/stream_profile.dart';
import '../../domain/stream_server_config.dart';

class StoredStreamConfig {
  const StoredStreamConfig({
    required this.serverConfig,
    required this.profile,
    required this.sourceType,
  });

  final StreamServerConfig serverConfig;
  final StreamProfile profile;
  final CaptureSourceType sourceType;
}

class StreamConfigStorage {
  static const _serverKey = 'live_stream.server_config';
  static const _profileKey = 'live_stream.profile';
  static const _sourceKey = 'live_stream.source_type';

  Future<StoredStreamConfig?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final serverText = preferences.getString(_serverKey);
    final profileText = preferences.getString(_profileKey);
    if (serverText == null && profileText == null) {
      return null;
    }

    final sourceName = preferences.getString(_sourceKey);
    return StoredStreamConfig(
      serverConfig: serverText == null
          ? StreamServerConfig.defaults()
          : StreamServerConfig.fromJson(
              jsonDecode(serverText) as Map<String, Object?>,
            ),
      profile: profileText == null
          ? StreamProfile.defaults()
          : StreamProfile.fromJson(
              jsonDecode(profileText) as Map<String, Object?>,
            ),
      sourceType: CaptureSourceType.values.firstWhere(
        (type) => type.name == sourceName,
        orElse: () => CaptureSourceType.camera,
      ),
    );
  }

  Future<void> save({
    required StreamServerConfig serverConfig,
    required StreamProfile profile,
    required CaptureSourceType sourceType,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _serverKey,
      jsonEncode(serverConfig.toJson(includeToken: false)),
    );
    await preferences.setString(_profileKey, jsonEncode(profile.toJson()));
    await preferences.setString(_sourceKey, sourceType.name);
  }
}
