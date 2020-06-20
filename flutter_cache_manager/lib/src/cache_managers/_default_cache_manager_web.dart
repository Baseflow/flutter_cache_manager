import '../../flutter_cache_manager.dart';
import 'default_cache_manager.dart' as shared;

class DefaultCacheManager extends BaseCacheManager implements shared.DefaultCacheManager{
  static const key = 'libCachedImageData';

  static DefaultCacheManager _instance;
  factory DefaultCacheManager() {
    _instance ??= DefaultCacheManager._();
    return _instance;
  }

  DefaultCacheManager._() : super(key);

  @override
  Future<String> getFilePath() async {
    throw UnsupportedError("File path is not supported on web");
  }
}