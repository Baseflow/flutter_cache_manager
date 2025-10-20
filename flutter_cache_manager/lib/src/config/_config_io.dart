import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/config/config.dart' as def;

class Config implements def.Config {
  Config(
    this.cacheKey, {
    Duration? stalePeriod,
    Duration? durationOnMaxAgeZero,
    int? maxNrOfCacheObjects,
    CacheInfoRepository? repo,
    FileSystem? fileSystem,
    FileService? fileService,
  })  : stalePeriod = stalePeriod ?? const Duration(days: 30),
        durationOnMaxAgeZero = durationOnMaxAgeZero ?? const Duration(days: 7),
        maxNrOfCacheObjects = maxNrOfCacheObjects ?? 200,
        repo = repo ?? _createRepo(cacheKey),
        fileSystem = fileSystem ?? IOFileSystem(cacheKey),
        fileService = fileService ??
            HttpFileService(
                durationOnMaxAgeZero: durationOnMaxAgeZero ??
                Duration(days: 7),
            );

  @override
  final CacheInfoRepository repo;

  @override
  final FileSystem fileSystem;

  @override
  final String cacheKey;

  @override
  final Duration stalePeriod;

  @override
  final Duration durationOnMaxAgeZero;

  @override
  final int maxNrOfCacheObjects;

  @override
  final FileService fileService;

  static CacheInfoRepository _createRepo(String key) {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return CacheObjectProvider(databaseName: key);
    }
    return JsonCacheInfoRepository(databaseName: key);
  }
}
