import 'dart:io';

import 'package:flutter_cache_manager/src/cache_object.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  // Tests with sqflite are broken, because sqflite doesn't provide testing yet.

  test('Test adding files to cache sql store', () async {
    var url =
        "https://cdn2.online-convert.com/example-file/raster%20image/png/example_small.png";
    var provider = await getDbProvider();
    await provider.open();
    await provider.updateOrInsert(new CacheObject(url));
    await provider.close();

    await provider.open();
    var storedObject = await provider.get(url);
    expect(storedObject, isNotNull);
    expect(storedObject.id, isNotNull);
  });
}

Future<CacheObjectProvider> getDbProvider() async {
  var storeKey = 'test';

  var databasesPath = await Directory.systemTemp.createTemp();
  var path = p.join(databasesPath.path, "$storeKey.db");

  try {
    await Directory(databasesPath.path).create(recursive: true);
  } catch (_) {}
  return new CacheObjectProvider(path);
}
