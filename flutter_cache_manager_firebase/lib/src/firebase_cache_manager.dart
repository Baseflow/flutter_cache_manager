import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:retry/retry.dart';

import 'firebase_http_file_service.dart';

/// Use [FirebaseCacheManager] if you want to download files from firebase storage
/// and store them in your local cache.
class FirebaseCacheManager extends CacheManager {
  static const defaultKey = 'firebaseCache';

  static final Map<String, FirebaseCacheManager> _instances = {};

  static RetryOptions? _retryOptions;

  static String? _bucket;

  factory FirebaseCacheManager({RetryOptions? retryOptions, String? bucket}) {
    final cacheKey = bucket ?? defaultKey;
    if (_instances.containsKey(cacheKey)) {
      return _instances[cacheKey]!;
    }
    _bucket = bucket ?? _bucket;
    _retryOptions = retryOptions ?? _retryOptions;
    final instance = FirebaseCacheManager._(key: cacheKey, retryOptions: _retryOptions, bucket: _bucket);
    _instances[cacheKey] = instance;
    return instance;
  }

  FirebaseCacheManager._({required String key, RetryOptions? retryOptions, String? bucket})
      : super(Config(key,
            fileService: FirebaseHttpFileService(
                retryOptions: retryOptions, bucket: bucket)));
}
