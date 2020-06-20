import '../../flutter_cache_manager.dart';
import '_default_cache_manager_unsupported.dart'
if (dart.library.html) '_default_cache_manager_web.dart'
if (dart.library.io) '_default_cache_manager_io.dart' as impl;

/// The DefaultCacheManager that can be easily used directly. The code of
/// this implementation can be used as inspiration for more complex cache
/// managers.
abstract class DefaultCacheManager implements BaseCacheManager {
  static DefaultCacheManager _instance;
  factory DefaultCacheManager() {
    _instance ??= impl.DefaultCacheManager();
    return _instance;
  }
}
