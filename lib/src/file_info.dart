import 'dart:io';

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

enum FileSource { NA, Cache, Online }

class FileInfo {
  FileInfo(this.file, this.source, this.validTill, this.originalUrl);

  String originalUrl;
  File file;
  FileSource source;
  DateTime validTill;
}
