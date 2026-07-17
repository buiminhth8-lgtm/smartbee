import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/features/live_stream/infrastructure/capture/desktop_screen_capture_adapter.dart';
import 'package:smartbee/features/live_stream/infrastructure/capture/webrtc_media_capture_service.dart';

void main() {
  test('Windows环境不会选择Android适配器', () {
    final service = WebRtcMediaCaptureService();
    expect(service.debugScreenCapturePlatformLabel, isNot('android'));
  });

  test('Windows适配器不调用Android权限API', () {
    const adapter = DesktopScreenCaptureAdapter(platformLabel: 'windows');
    expect(adapter.platformLabel, 'windows');
  });
}
