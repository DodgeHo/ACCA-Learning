// Platform-specific database implementation selector.
//
// On native (Android/iOS/desktop) we use `db_native.dart` (sqflite).
// On web we use `db_web.dart` (sembast backed by IndexedDB).

export 'db_native.dart' if (dart.library.html) 'db_web.dart';
