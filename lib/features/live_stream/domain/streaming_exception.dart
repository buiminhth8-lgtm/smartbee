enum StreamingErrorCode {
  permissionDenied,
  permissionCancelled,
  cameraNotFound,
  screenCaptureUnavailable,
  captureSourceNotSelected,
  captureStoppedBySystem,
  foregroundServiceFailed,
  emptyVideoTrack,
  rendererInitializationFailed,
  invalidServerConfig,
  serverUnreachable,
  authenticationFailed,
  publishConflict,
  whipHttpFailed,
  invalidOfferSdp,
  invalidAnswerSdp,
  setRemoteDescriptionFailed,
  iceGatheringTimeout,
  iceConnectionTimeout,
  networkConnectionRefused,
  sdpNegotiationFailed,
  iceConnectionFailed,
  unsupportedPlatform,
  unsupportedProtocol,
  unknown,
}

class StreamingException implements Exception {
  const StreamingException(this.code, this.message, {this.cause});

  final StreamingErrorCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

StreamingException normalizeStreamingException(Object error) {
  if (error is StreamingException) {
    return error;
  }

  final text = error.toString();
  final lower = text.toLowerCase();
  if (lower.contains('permission') ||
      lower.contains('denied') ||
      lower.contains('notallowed')) {
    return StreamingException(
      StreamingErrorCode.permissionDenied,
      '权限被拒绝，请在系统设置中允许摄像头、麦克风或屏幕录制权限。',
      cause: error,
    );
  }
  if (lower.contains('notfound') || lower.contains('device')) {
    return StreamingException(
      StreamingErrorCode.cameraNotFound,
      '没有找到可用摄像头。',
      cause: error,
    );
  }
  if (lower.contains('cancel')) {
    return StreamingException(
      StreamingErrorCode.permissionCancelled,
      '用户取消了系统授权或选择窗口。',
      cause: error,
    );
  }

  return StreamingException(
    StreamingErrorCode.unknown,
    '操作失败，请检查设备权限、网络和服务器配置。',
    cause: error,
  );
}
