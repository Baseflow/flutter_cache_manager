import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/config/config.dart' as def;

import '../storage/file_system/file_system.dart';

class Config implements def.Config {
  Config(
    this.cacheKey, {
    Duration? stalePeriod,
    int? maxNrOfCacheObjects,
    CacheInfoRepository? repo,
    FileSystem? fileSystem,
    FileService? fileService,
  })  : stalePeriod = stalePeriod ?? const Duration(days: 30),
        maxNrOfCacheObjects = maxNrOfCacheObjects ?? 200,
        repo = repo ??
            IndexedDbCacheInfoRepository(
                databaseName: 'flutter_cache_manager_$cacheKey'),
        fileSystem = fileSystem ??
            IndexedDbFileSystem('flutter_cache_manager_$cacheKey'),
        fileService = fileService ?? HttpFileService();

  @override
  final CacheInfoRepository repo;

  @override
  final FileSystem fileSystem;

  @override
  final String cacheKey;

  @override
  final Duration stalePeriod;

  @override
  final int maxNrOfCacheObjects;

  @override
  final FileService fileService;
}
