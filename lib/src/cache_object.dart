// CacheManager for Flutter
// Copyright (c) 2017 Rene Floor
// Released under MIT License.

import 'dart:io';

import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';

///Cache information of one file
class CacheObject {
  static const _keyFilePath = "relativePath";
  static const _keyValidTill = "validTill";
  static const _keyETag = "ETag";
  static const _keyTouched = "touched";

  String getFilePath() {
    if (relativePath == null) {
      return null;
    }
    return directory.path + relativePath;
  }

  String get relativePath => _map[_keyFilePath];
  String get eTag => _map[_keyETag];
  DateTime get validTill {
    if (_map.containsKey(_keyValidTill)) {
      return new DateTime.fromMillisecondsSinceEpoch(_map[_keyValidTill]);
    }
    return null;
  }


  DateTime touched;
  final String url;
  final Directory directory;

  Lock lock;
  Map _map;

  CacheObject(this.url, this.directory, {this.lock}) {
    _map = new Map();
    touch();
    if (lock == null) {
      lock = new Lock();
    }
  }

  CacheObject.fromMap(this.url, this.directory, Map map, {this.lock}) {
    _map = map;

    if (_map.containsKey(_keyTouched)) {
      touched = new DateTime.fromMillisecondsSinceEpoch(_map[_keyTouched]);
    } else {
      touch();
    }
    if (lock == null) {
      lock = new Lock();
    }
  }

  Map toMap() {
    return _map;
  }

  touch() {
    touched = new DateTime.now();
    _map[_keyTouched] = touched.millisecondsSinceEpoch;
  }

  setDataFromHeaders(Map<String, String> headers) {
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

    _map[_keyValidTill] =
        new DateTime.now().add(ageDuration).millisecondsSinceEpoch;

    if (headers.containsKey("etag")) {
      _map[_keyETag] = headers["etag"];
    }

    var fileExtension = "";
    if (headers.containsKey("content-type")) {
      var type = headers["content-type"].split("/");
      if (type.length == 2) {
        fileExtension = ".${type[1]}";
      }
    }

    var oldPath = getFilePath();
    if (oldPath != null && !oldPath.endsWith(fileExtension)) {
      removeOldFile(oldPath);
      _map[_keyFilePath] = null;
    }

    if (relativePath == null) {
      var fileName = "cache/${new Uuid().v1()}$fileExtension";
      _map[_keyFilePath] = fileName;
    }
  }

  removeOldFile(String filePath) async {
    var file = new File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  setRelativePath(String path) {
    _map[_keyFilePath] = path;
  }
}
