import 'dart:io';
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

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool loading = false;
  FileInfo fileInfo;
  String error;

  _downloadFile() {
    if (loading) {
      return;
    }

    setState(() {
      loading = true;
      fileInfo = null;
      error = null;
    });

    var url = 'https://cdn2.online-convert.com/example-file/raster%20image/png/example_small.png';

    DefaultCacheManager().getFile(url).listen((f) {
      setState(() {
        loading = false;
        fileInfo = f;
        error = null;
      });
    }).onError((e) {
      setState(() {
        loading = false;
        fileInfo = null;
        error = e.toString();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    Widget fab;

    if (loading) {
      body = Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 50.0,
              height: 50.0,
              child: CircularProgressIndicator(),
            ),
            SizedBox(width: 20.0),
            Text("Downloading"),
          ],
        ),
      );
    } else {
      final List<Widget> children = [];
      if (fileInfo != null) {
        if (fileInfo != null) {
          children.add(
            ListTile(
              title: Text("Original URL"),
              subtitle: Text(fileInfo.originalUrl),
            ),
          );

          if (fileInfo.file != null) {
            File file = fileInfo.file;
            children.add(
              ListTile(
                title: Text("Local file path"),
                subtitle: Text(file.path),
              ),
            );
          }

          children.add(
            ListTile(
              title: Text("Loaded from"),
              subtitle: Text(fileInfo.source.toString()),
            ),
          );

          children.add(
            ListTile(
              title: Text("Valid Until"),
              subtitle: Text(fileInfo.validTill.toIso8601String()),
            ),
          );
        }

        if (error != null) {
          ListTile(
            title: Text("Error"),
            subtitle: Text(error.toString()),
          );
        }

        children.add(
          Padding(
            padding: EdgeInsets.all(10.0),
            child: RaisedButton(
              child: Text('CLEAR CACHE'),
              onPressed: () {
                DefaultCacheManager().emptyCache();
                this.setState(() {
                  fileInfo = null;
                });
              },
            ),
          ),
        );
      } else {
        children.add(ListTile(title: Text("Tap the floating action button to download.")));
      }

      body = ListView(children: children);

      fab = FloatingActionButton(
        onPressed: _downloadFile,
        tooltip: 'Download',
        child: Icon(Icons.cloud_download),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Flutter Cache Manager Demo"),
      ),
      body: body,
      floatingActionButton: fab,
    );
  }
}
