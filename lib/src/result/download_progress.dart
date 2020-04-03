import 'package:flutter_cache_manager/src/result/file_response.dart';

/// Progress of the file that is being downloaded from the [originalUrl].
class DownloadProgress extends FileResponse {
  const DownloadProgress(String originalUrl, this.totalSize, this.downloaded)
      : super(originalUrl);

  /// download progress as an integer between 0 and 100,
  /// with 100 meaning the download is complete.
  /// When the final size is unknown progress is always null.
  int get progress{
    // ignore: avoid_returning_null
    if(totalSize == null) return null;
    return  ((downloaded * 100) / totalSize).floor();
  }

  /// Final size of the download. If total size is unknown this will be null.
  final int totalSize;
  /// Total of currently downloaded bytes.
  final int downloaded;
}
