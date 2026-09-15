export 'cache_info_repository.dart';
export 'cache_object_provider.dart';
export 'json_cache_info_repository.dart';
export 'non_storing_object_provider.dart';

// Note: indexed_db_cache_info_repository.dart is web-only and not exported here
// to avoid dart:js_interop import errors on non-web platforms.
// Web code should import it directly when needed.
