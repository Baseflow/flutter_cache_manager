import 'package:flutter_cache_manager/src/storage/cache_info_repositories/cache_info_repository.dart';
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart';

import '_config_unsupported.dart'
    if (dart.library.html) '_config_web.dart'
    if (dart.library.io) '_config_io.dart' as impl;

abstract class Config {
  factory Config(
      String cacheKey, {
      Duration maxAgeCacheObject,
      int maxNrOfCacheObjects,
    CacheInfoRepository repo,
    FileSystem fileSystem,
  }) = impl.Config;

  String get cacheKey;
  Duration get maxAgeCacheObject;
  int get maxNrOfCacheObjects;
  CacheInfoRepository get repo;
  FileSystem get fileSystem;
}
