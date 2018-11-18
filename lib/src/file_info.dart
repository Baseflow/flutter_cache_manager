import 'dart:io';

enum FileSource { NA, Cache, Online }

class FileInfo {
  FileInfo(this.file, this.source, this.validTill, this.originalUrl);

  String originalUrl;
  File file;
  FileSource source;
  DateTime validTill;
}
