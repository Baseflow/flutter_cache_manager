import 'dart:io';

import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_cache_manager/src/storage/cache_object_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  // Tests with sqflite are broken, because sqflite doesn't provide testing yet.
//  test('Test adding files to cache sql store', () async {
//    final url = 'https://cdn2.online-convert.com/example-file/raster%20image/png/example_small.png';
//    final provider = await getDbProvider();
//    await provider.open();
//    await provider.updateOrInsert(CacheObject(url));
//    await provider.close();
//    await provider.open();
//    final storedObject = await provider.get(url);
//    expect(storedObject, isNotNull);
//    expect(storedObject.id, isNotNull);
//  });
}

Future<CacheObjectProvider> getDbProvider() async {
  final databasesPath = await Directory.systemTemp.createTemp();
  try {
    await Directory(databasesPath.path).create(recursive: true);
  } catch (_) {}
  return CacheObjectProvider(p.join(databasesPath.path, 'test.db'));
}