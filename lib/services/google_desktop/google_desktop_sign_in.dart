// Elige la versión para PC (con dart:io) o una vacía para la web.
export 'google_desktop_stub.dart'
    if (dart.library.io) 'google_desktop_io.dart';
