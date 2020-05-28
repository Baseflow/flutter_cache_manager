import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'firebase_http_file_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Use [FirebaseCacheManager] if you want to download files from firebase storage
/// and store them in your local cache.
class FirebaseCacheManager extends BaseCacheManager {
  static const key = 'firebaseCache';

  static FirebaseCacheManager _instance;

  factory FirebaseCacheManager() {
    _instance ??= FirebaseCacheManager._();
    return _instance;
  }

  FirebaseCacheManager._() : super(key, fileService: FirebaseHttpFileService());

  @override
  Future<String> getFilePath() async {
    var directory = await getTemporaryDirectory();
    return p.join(directory.path, key);
  }
}