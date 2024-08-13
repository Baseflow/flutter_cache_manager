import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:retry/retry.dart';

import 'firebase_http_file_service.dart';

/// Use [FirebaseCacheManager] if you want to download files from firebase storage
/// and store them in your local cache.
class FirebaseCacheManager extends CacheManager {
  static const key = 'firebaseCache';

  static final FirebaseCacheManager _instance =
      FirebaseCacheManager._(retryOptions: retryOptions, bucket: bucket);

  static RetryOptions? retryOptions;

  static String? bucket;

  factory FirebaseCacheManager({RetryOptions? retryOptions, String? bucket}) {
    bucket = bucket;
    retryOptions = retryOptions;
    return _instance;
  }

  FirebaseCacheManager._({RetryOptions? retryOptions, String? bucket})
      : super(Config(key,
            fileService: FirebaseHttpFileService(
                retryOptions: retryOptions, bucket: bucket)));
}
