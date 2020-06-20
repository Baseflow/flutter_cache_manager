import '../../flutter_cache_manager.dart';
import 'default_cache_manager.dart' as shared;

class DefaultCacheManager extends BaseCacheManager implements shared.DefaultCacheManager{
  factory DefaultCacheManager() {
    throw UnsupportedError("Platform is not supported");
  }

  DefaultCacheManager._() : super(null);

  @override
  Future<String> getFilePath() async {
    throw UnsupportedError("Platform is not supported");
  }
}