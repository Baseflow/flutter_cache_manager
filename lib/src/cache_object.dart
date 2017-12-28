// CacheManager for Flutter
// Copyright (c) 2017 Rene Floor
// Released under MIT License.

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

///Cache information of one file
class CacheObject {
  String get filePath {
    if (_map.containsKey("path")) {
      return _map["path"];
    }
    return null;
  }

  DateTime get validTill {
    if (_map.containsKey("validTill")) {
      return new DateTime.fromMillisecondsSinceEpoch(_map["validTill"]);
    }
    return null;
  }

  String get eTag {
    if (_map.containsKey("ETag")) {
      return _map["ETag"];
    }
    return null;
  }

  DateTime touched;
  String url;

  Object lock;
  Map _map;

  CacheObject(String url) {
    this.url = url;
    _map = new Map();
    touch();
    lock = new Object();
  }

  CacheObject.fromMap(String url, Map map) {
    this.url = url;
    _map = map;

    if (_map.containsKey("touched")) {
      touched = new DateTime.fromMillisecondsSinceEpoch(_map["touched"]);
    } else {
      touch();
    }

    lock = new Object();
  }

  Map toMap() {
    return _map;
  }

  touch() {
    touched = new DateTime.now();
    _map["touched"] = touched.millisecondsSinceEpoch;
  }

  setDataFromHeaders(Map<String, String> headers) async {
    //Without a cache-control header we keep the file for a week
    var ageDuration = new Duration(days: 7);

    if (headers.containsKey("cache-control")) {
      var cacheControl = headers["cache-control"];
      var controlSettings = cacheControl.split(", ");
      controlSettings.forEach((setting) {
        if (setting.startsWith("max-age=")) {
          var validSeconds =
              int.parse(setting.split("=")[1], onError: (source) => 0);
          if (validSeconds > 0) {
            ageDuration = new Duration(seconds: validSeconds);
          }
        }
      });
    }

    _map["validTill"] =
        new DateTime.now().add(ageDuration).millisecondsSinceEpoch;

    if (headers.containsKey("etag")) {
      _map["ETag"] = headers["etag"];
    }

    var fileExtension = "";
    if (headers.containsKey("content-type")) {
      var type = headers["content-type"].split("/");
      if (type.length == 2) {
        fileExtension = ".${type[1]}";
      }
    }

    if (filePath != null && !filePath.endsWith(fileExtension)) {
      removeOldFile(filePath);
      _map["path"] = null;
    }

    if (filePath == null) {
      Directory directory = await getTemporaryDirectory();
      var folder = new Directory("${directory.path}/cache");
      var fileName = "${new Uuid().v1()}${fileExtension}";
      _map["path"] = "${folder.path}/${fileName}";
    }

    var folder = new File(filePath).parent;
    if (!(await folder.exists())) {
      folder.createSync(recursive: true);
    }
  }

  removeOldFile(String filePath) async {
    var file = new File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  setPath(String path) {
    _map["path"] = path;
  }
}
