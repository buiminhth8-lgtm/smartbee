import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/app/smartbee_app.dart';

import 'features/live_stream/webrtc_test_binding.dart';

void main() {
  setUp(mockWebRtcRenderer);

  testWidgets('默认地图功能不被破坏', (tester) async {
    await tester.pumpWidget(const SmartbeeApp());
    await tester.pumpAndSettle();

    expect(find.text('地图示例'), findsOneWidget);
    expect(find.textContaining('经度'), findsOneWidget);
    expect(find.textContaining('纬度'), findsOneWidget);
  });
}
