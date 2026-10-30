import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class InterlacedProgress extends DownloadProgress {
  InterlacedProgress(
      super.originalUrl, super.totalSize, super.downloaded, this.data);

  final Uint8List data;
}
