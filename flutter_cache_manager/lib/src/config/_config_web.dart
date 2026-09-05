import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/config/config.dart' as def;
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/indexed_db_cache_info_repository.dart';
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart';
import 'package:flutter_cache_manager/src/storage/file_system/indexed_db_file_system.dart';

class Config implements def.Config {
  Config(
    this.cacheKey, {
    Duration? stalePeriod,
    int? maxNrOfCacheObjects,
    CacheInfoRepository? repo,
    FileSystem? fileSystem,
    FileService? fileService,
  }) : stalePeriod = stalePeriod ?? const Duration(days: 30),
       maxNrOfCacheObjects = maxNrOfCacheObjects ?? 200,
       repo =
           repo ??
           IndexedDbCacheInfoRepository(
             databaseName: 'flutter_cache_manager_$cacheKey',
           ),
       fileSystem =
           fileSystem ?? IndexedDbFileSystem('flutter_cache_manager_$cacheKey'),
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
