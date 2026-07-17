import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

int rendererDisposeCount = 0;
int rendererInitializeCount = 0;
final List<String> rendererBoundStreamIds = <String>[];

void mockWebRtcRenderer() {
  TestWidgetsFlutterBinding.ensureInitialized();
  rendererDisposeCount = 0;
  rendererInitializeCount = 0;
  rendererBoundStreamIds.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('FlutterWebRTC.Method'), (
        call,
      ) async {
        switch (call.method) {
          case 'createVideoRenderer':
            rendererInitializeCount++;
            return {'textureId': 1};
          case 'videoRendererSetSrcObject':
            final arguments = call.arguments as Map<dynamic, dynamic>;
            rendererBoundStreamIds.add('${arguments['streamId']}');
            return null;
          case 'videoRendererDispose':
            rendererDisposeCount++;
            return null;
        }
        return null;
      });
}
