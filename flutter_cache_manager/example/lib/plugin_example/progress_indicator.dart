import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// A centered and sized [CircularProgressIndicator] to show download progress
/// in the [DownloadPage].
class ProgressIndicator extends StatelessWidget {
  final DownloadProgress? progress;

  const ProgressIndicator({super.key, this.progress});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator.adaptive(
              value: progress?.progress,
            ),
          ),
          const SizedBox(width: 20),
          const Text('Downloading'),
        ],
      ),
    );
  }
}
