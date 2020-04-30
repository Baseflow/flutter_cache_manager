import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Cache Manager Demo',
      home: MyHomePage(),
    );
  }
}

const url =
    'https://file-examples.com/wp-content/uploads/2018/04/file_example_AVI_1280_1_5MG.avi';

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Stream<FileResponse> fileStream;

  void _downloadFile() {
    setState(() {
      fileStream = DefaultCacheManager().getFileStream(url, withProgress: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (fileStream == null) {
      return Scaffold(
        appBar: _appBar(),
        body: const ListTile(
            title: Text('Tap the floating action button to download.')),
        floatingActionButton: Fab(
          downloadFile: _downloadFile,
        ),
      );
    }
    return DownloadPage(
      fileStream: fileStream,
      downloadFile: _downloadFile,
      clearCache: _clearCache,
    );
  }

  void _clearCache() {
    DefaultCacheManager().emptyCache();
    setState(() {
      fileStream = null;
    });
  }
}

class DownloadPage extends StatelessWidget {
  final Stream<FileResponse> fileStream;
  final VoidCallback downloadFile;
  final VoidCallback clearCache;
  const DownloadPage(
      {Key key, this.fileStream, this.downloadFile, this.clearCache})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FileResponse>(
      stream: fileStream,
      builder: (context, snapshot) {
        Widget body;

        var loading = !snapshot.hasData || snapshot.data is DownloadProgress;

        if (snapshot.hasError) {
          body = ListTile(
            title: const Text('Error'),
            subtitle: Text(snapshot.error.toString()),
          );
        } else if (loading) {
          body = ProgressIndicator(progress: snapshot.data as DownloadProgress);
        } else {
          body = FileInfoWidget(
            fileInfo: snapshot.data as FileInfo,
            clearCache: clearCache,
          );
        }

        return Scaffold(
          appBar: _appBar(),
          body: body,
          floatingActionButton: !loading
              ? Fab(
                  downloadFile: downloadFile,
                )
              : null,
        );
      },
    );
  }
}

AppBar _appBar() {
  return AppBar(
    title: const Text('Flutter Cache Manager Demo'),
  );
}

class Fab extends StatelessWidget {
  final VoidCallback downloadFile;
  const Fab({Key key, this.downloadFile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: downloadFile,
      tooltip: 'Download',
      child: Icon(Icons.cloud_download),
    );
  }
}

class ProgressIndicator extends StatelessWidget {
  final DownloadProgress progress;
  const ProgressIndicator({Key key, this.progress}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 50.0,
            height: 50.0,
            child: CircularProgressIndicator(
              value: progress?.progress,
            ),
          ),
          const SizedBox(width: 20.0),
          const Text('Downloading'),
        ],
      ),
    );
  }
}

class FileInfoWidget extends StatelessWidget {
  final FileInfo fileInfo;
  final VoidCallback clearCache;

  const FileInfoWidget({Key key, this.fileInfo, this.clearCache})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        ListTile(
          title: const Text('Original URL'),
          subtitle: Text(fileInfo.originalUrl),
        ),
        if (fileInfo.file != null)
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
          child: RaisedButton(
            child: const Text('CLEAR CACHE'),
            onPressed: clearCache,
          ),
        ),
      ],
    );
  }
}
