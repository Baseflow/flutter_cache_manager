import 'dart:async';
import 'dart:typed_data';


abstract class CacheFile {
    Future<bool> exists();
    Future<void> delete();
    Future<void> createParent();
    StreamSink<List<int>> openWrite();
    Future writeAsBytes(Uint8List bytes);
    String get path;

    /// Read the entire file contents as a list of bytes. Returns a
    /// `Future<Uint8List>` that completes with the list of bytes that is the
    /// contents of the file.
    Future<Uint8List> readAsBytes();
}