import '_default_object_provider_unsupported.dart'
    if (dart.library.html) '_default_object_provider_web.dart'
    if (dart.library.io) '_default_object_provider_io.dart' as impl;

import 'cache_info_repository.dart';

abstract class DefaultObjectProvider implements CacheInfoRepository {
  factory DefaultObjectProvider() = impl.DefaultObjectProvider;
}
