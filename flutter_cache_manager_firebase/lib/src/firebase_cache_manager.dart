import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'firebase_http_file_service.dart';

/// Use [FirebaseCacheManager] if you want to download files from firebase storage
/// and store them in your local cache.
class FirebaseCacheManager extends CacheManager {
  static const key = 'firebaseCache';

  static FirebaseCacheManager? _instance;

  factory FirebaseCacheManager() {
    _instance ??= FirebaseCacheManager._();
    return _instance!;
  }

  FirebaseCacheManager._()
      : super(Config(key, fileService: FirebaseHttpFileService()));
}
