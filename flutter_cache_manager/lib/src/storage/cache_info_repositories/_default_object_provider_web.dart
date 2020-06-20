import 'package:flutter_cache_manager/src/storage/cache_info_repositories/non_storing_object_provider.dart';

import 'default_object_provider.dart' as shared;

class DefaultObjectProvider extends NonStoringObjectProvider
    implements shared.DefaultObjectProvider {
  DefaultObjectProvider() : super();
}
