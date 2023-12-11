class QueueItem {
  final String url;
  final String key;
  final Map<String, String>? headers;

  const QueueItem(this.url, this.key, this.headers);
}
