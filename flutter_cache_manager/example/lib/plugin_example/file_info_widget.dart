import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// A [Widget] showing all available information about the downloaded file
class FileInfoWidget extends StatelessWidget {
  final FileInfo fileInfo;
  final VoidCallback? clearCache;
  final VoidCallback? removeFile;

  const FileInfoWidget({
    super.key,
    required this.fileInfo,
    this.clearCache,
    this.removeFile,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        ListTile(
          title: const Text('Original URL'),
          subtitle: Text(fileInfo.originalUrl),
        ),
        ListTile(
          title: const Text('Local file path'),
          subtitle: Text(fileInfo.file.path),
        ),
        ListTile(
          title: const Text('Loaded from'),
          subtitle: Text(fileInfo.source.toString()),
        ),
        ListTile(
          title: const Text('Valid Until'),
          subtitle: Text(fileInfo.validTill.toIso8601String()),
        ),
        Padding(
          padding: const EdgeInsets.all(10.0),
          // ignore: deprecated_member_use
          child: ElevatedButton(
            onPressed: clearCache,
            child: const Text('CLEAR CACHE'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10.0),
          // ignore: deprecated_member_use
          child: ElevatedButton(
            onPressed: removeFile,
            child: const Text('REMOVE FILE'),
          ),
        ),
      ],
    );
  }
}
