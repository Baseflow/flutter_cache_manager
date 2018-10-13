import 'dart:io';

enum FileSource { NA, Cache, Online }

class FileInfo {
  FileInfo(this.file, this.source, this.age);

  File file;
  FileSource source;
  DateTime age;
}
