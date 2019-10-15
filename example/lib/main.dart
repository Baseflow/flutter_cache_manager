import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FileInfo fileInfo;
  String error;

  _downloadFile() {
    var url =
        'https://cdn2.online-convert.com/example-file/raster%20image/png/example_small.png';

    DefaultCacheManager().getFile(url).listen((f) {
      setState(() {
        fileInfo = f;
        error = null;
      });
    }).onError((e) {
      setState(() {
        fileInfo = null;
        error = e.toString();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    var path = "N/A";
    if (fileInfo?.file != null) {
      path = fileInfo.file.path;
    }
    var from = "N/A";
    if (fileInfo != null) {
      from = fileInfo.source.toString();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Local filePath:',
            ),
            Text(
              path,
            ),
            Text(
              'From: $from',
            ),
            Text('Error: $error'),
            Padding(
              padding: const EdgeInsets.only(top: 32.0),
              child: RaisedButton(
                child: Text('CLEAR CACHE'),
                onPressed: () {
                  DefaultCacheManager().emptyCache();
                },
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _downloadFile,
        tooltip: 'Download',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
