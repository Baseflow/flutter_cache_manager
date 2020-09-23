import 'package:flutter_cache_manager/src/storage/cache_info_repositories/cache_info_repository.dart';
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart';
import 'package:flutter_cache_manager/src/web/file_service.dart';

import 'config.dart' as def;

class Config implements def.Config {
  Config(String cacheKey, {
    Duration maxAgeCacheObject,
    int maxNrOfCacheObjects,
    CacheInfoRepository repo,
    FileSystem fileSystem,
    FileService fileService,
  }) {
    throw UnsupportedError('Platform is not supported');
  }

  @override
  CacheInfoRepository get repo => throw UnimplementedError();

  @override
  FileSystem get fileSystem => throw UnimplementedError();

  @override
  String get cacheKey => throw UnimplementedError();

  @override
  Duration get maxAgeCacheObject => throw UnimplementedError();

  @override
  int get maxNrOfCacheObjects => throw UnimplementedError();

  @override
  // TODO: implement fileService
  FileService get fileService => throw UnimplementedError();
}
