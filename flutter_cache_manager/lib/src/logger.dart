import '../flutter_cache_manager.dart';

CacheLogger cacheLogger = CacheLogger();

enum CacheManagerLogLevel {
  none,
  warning,
  debug,
  verbose,
}

class CacheLogger {
  void log(String message, CacheManagerLogLevel level) {
    if (CacheManager.logLevel.index >= level.index) {
      print(message);
    }
  }
}
