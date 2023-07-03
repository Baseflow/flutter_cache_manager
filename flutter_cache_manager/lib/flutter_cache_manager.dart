/// Generic cache manager for flutter.
/// Saves web files on the storages of the device and saves the cache info using sqflite
library flutter_cache_manager;

export 'src/cache_manager.dart';
export 'src/cache_managers/cache_managers.dart';
export 'src/compat/file_fetcher.dart';
export 'src/config/config.dart';
export 'src/logger.dart';
export 'src/result/result.dart';
export 'src/storage/cache_info_repositories/cache_info_repositories.dart';
export 'src/web/file_service.dart';
export 'src/web/web_helper.dart' show HttpExceptionWithStatus;
