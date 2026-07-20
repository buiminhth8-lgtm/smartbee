export 'map_tile_http_client_common.dart';
export 'map_tile_http_client_stub.dart'
    if (dart.library.io) 'map_tile_http_client_io.dart'
    if (dart.library.js_interop) 'map_tile_http_client_web.dart';
