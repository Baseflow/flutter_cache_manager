import 'dart:io';

import 'package:meta/meta.dart';

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

enum FileSource { NA, Cache, Online }

@immutable
class FileInfo {
  const FileInfo(this.file, this.source, this.validTill, this.originalUrl);

  final String originalUrl;
  final File file;
  final FileSource source;
  final DateTime validTill;
}
