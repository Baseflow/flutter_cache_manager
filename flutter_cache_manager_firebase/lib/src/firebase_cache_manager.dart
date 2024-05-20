import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:retry/retry.dart';

import 'firebase_http_file_service.dart';

/// Use [FirebaseCacheManager] if you want to download files from firebase storage
/// and store them in your local cache.
class FirebaseCacheManager extends CacheManager {
  static const key = 'firebaseCache';

  static final FirebaseCacheManager _instance = FirebaseCacheManager._();

  final RetryOptions? retryOptions;

  final RetryOptions? retryOptions;

  factory FirebaseCacheManager() {
    return _instance;
  }

  FirebaseCacheManager.retry({this.retryOptions = const RetryOptions()}): super(Config(key, fileService: FirebaseHttpFileService(retryOptions: retryOptions)));

  FirebaseCacheManager._({this.retryOptions})
      : super(Config(key, fileService: FirebaseHttpFileService()));
}
