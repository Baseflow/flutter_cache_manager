import 'dart:typed_data';

import 'package:file/file.dart';

abstract class CacheFile {
    Future<bool> exists();
    Future<void> delete();
    Future<void> createParent();
    IOSink openWrite();
    Future writeAsBytes(Uint8List bytes);
}