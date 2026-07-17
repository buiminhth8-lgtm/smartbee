enum CaptureSourceType {
  camera,
  screen;

  String get label => switch (this) {
    CaptureSourceType.camera => '摄像头',
    CaptureSourceType.screen => '屏幕',
  };
}
