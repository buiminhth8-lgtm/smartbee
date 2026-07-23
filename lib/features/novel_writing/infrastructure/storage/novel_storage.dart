export 'novel_storage_common.dart';
export 'novel_storage_stub.dart'
    if (dart.library.io) 'novel_storage_io.dart'
    if (dart.library.js_interop) 'novel_storage_web.dart';
