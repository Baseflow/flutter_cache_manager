import 'package:flutter_cache_manager/src/web/file_service.dart';

class QueueItem {
  final String url;
  final String key;
  final Map<String, String>? headers;
  final CancellationToken? cancellationToken;

  const QueueItem(this.url, this.key, this.headers, [this.cancellationToken]);
}
