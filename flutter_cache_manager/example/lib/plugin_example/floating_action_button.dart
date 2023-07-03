import 'package:flutter/material.dart';

/// A [FloatingActionButton] used for downloading a file in [CacheManagerPage]
class Fab extends StatelessWidget {
  final VoidCallback downloadFile;

  const Fab({
    required this.downloadFile,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: downloadFile,
      tooltip: 'Download',
      child: const Icon(Icons.cloud_download),
    );
  }
}
