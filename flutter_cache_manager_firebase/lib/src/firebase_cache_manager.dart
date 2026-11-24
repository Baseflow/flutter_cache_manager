import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:retry/retry.dart';

import 'firebase_http_file_service.dart';

/// Use [FirebaseCacheManager] if you want to download files from firebase storage
/// and store them in your local cache.
class FirebaseCacheManager extends CacheManager {
  static const key = 'firebaseCache';

  static final Map<String, FirebaseCacheManager> _instances = {};

  factory FirebaseCacheManager({RetryOptions? retryOptions, String? bucket}) {
    final cacheKey = bucket ?? key;
    return _instances.putIfAbsent(
      cacheKey,
      () => FirebaseCacheManager._(
        key: cacheKey,
        retryOptions: retryOptions,
        bucket: bucket,
      ),
    );
  }

  FirebaseCacheManager._({
    required String key,
    RetryOptions? retryOptions,
    String? bucket,
  }) : super(
         Config(
           key,
           fileService: FirebaseHttpFileService(
             retryOptions: retryOptions,
             bucket: bucket,
           ),
         ),
       );
}
