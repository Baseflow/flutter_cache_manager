import 'dart:typed_data';

import 'package:file/file.dart';

abstract class CacheFile {
    Future<bool> exists();
    Future<void> delete();
    Future<void> createParent();
    IOSink openWrite();
    Future writeAsBytes(Uint8List bytes);

    /// Read the entire file contents as a list of bytes. Returns a
    /// `Future<Uint8List>` that completes with the list of bytes that is the
    /// contents of the file.
    Future<Uint8List> readAsBytes();
}