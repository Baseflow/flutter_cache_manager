import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Simple test app to verify IndexedDB caching works on Flutter web
/// Run with: flutter run -d chrome lib/test_indexeddb.dart
void main() {
  // Enable verbose logging to see caching in action
  CacheManager.logLevel = CacheManagerLogLevel.verbose;
  runApp(const IndexedDBTestApp());
}

class IndexedDBTestApp extends MaterialApp {
  const IndexedDBTestApp({super.key})
      : super(
          home: const IndexedDBTestPage(),
          title: 'IndexedDB Cache Test',
        );
}

class IndexedDBTestPage extends StatefulWidget {
  const IndexedDBTestPage({super.key});

  @override
  State<IndexedDBTestPage> createState() => _IndexedDBTestPageState();
}

class _IndexedDBTestPageState extends State<IndexedDBTestPage> {
  // Using a reliable CDN image that supports CORS
  final String testUrl = 'https://i.imgur.com/7j7W5eq.jpeg';
  String status = 'Ready';
  FileInfo? cachedFile;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IndexedDB Cache Test'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Flutter Cache Manager - IndexedDB Test',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (cachedFile != null) ...[
                Container(
                  width: 400,
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Image.network(
                    testUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text('Failed to load image'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Source: ${cachedFile!.source.name}',
                  style: TextStyle(
                    color: cachedFile!.source == FileSource.Cache
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('Valid until: ${cachedFile!.validTill}'),
              ],
              const SizedBox(height: 32),
              Text(
                status,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (isLoading) const CircularProgressIndicator(),
              if (!isLoading) ...[
                ElevatedButton.icon(
                  onPressed: _downloadFile,
                  icon: const Icon(Icons.download),
                  label: const Text('Download & Cache Image'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadFromCache,
                  icon: const Icon(Icons.cached),
                  label: const Text('Load from Cache'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _clearCache,
                  icon: const Icon(Icons.delete),
                  label: const Text('Clear Cache'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '💡 Test Instructions:\n'
                  '1. Click "Download & Cache Image" - should show source: Online\n'
                  '2. Refresh the page (F5)\n'
                  '3. Click "Load from Cache" - should show source: Cache\n'
                  '4. Open DevTools → Application → IndexedDB to see stored data',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadFile() async {
    setState(() {
      isLoading = true;
      status = 'Downloading image...';
    });

    try {
      final info = await DefaultCacheManager().getFileFromCache(testUrl);

      setState(() {
        cachedFile = info;
        isLoading = false;
        status =
            'Image downloaded and cached! Source: ${info?.source.name ?? "Unknown"}';
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        status = 'Error: $e';
      });
    }
  }

  Future<void> _loadFromCache() async {
    setState(() {
      isLoading = true;
      status = 'Loading from cache...';
    });

    try {
      final info = await DefaultCacheManager().getFileFromCache(testUrl);

      if (info == null) {
        setState(() {
          isLoading = false;
          status = 'No cached file found. Download first!';
          cachedFile = null;
        });
        return;
      }

      setState(() {
        cachedFile = info;
        isLoading = false;
        status = 'Loaded from cache! Source: ${info.source.name}';
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        status = 'Error loading from cache: $e';
      });
    }
  }

  Future<void> _clearCache() async {
    setState(() {
      isLoading = true;
      status = 'Clearing cache...';
    });

    try {
      await DefaultCacheManager().emptyCache();

      setState(() {
        cachedFile = null;
        isLoading = false;
        status = 'Cache cleared!';
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        status = 'Error clearing cache: $e';
      });
    }
  }
}
