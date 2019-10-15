import 'dart:async';

import 'package:flutter_cache_manager/src/cache_object.dart';

class MockCacheObjectProvider extends CacheObjectProvider {
  final caches = <CacheObject>[];
  @override
  Future open() {
    return Future.value();
  }

  @override
  Future close() {
    caches.clear();
    return Future.value();
  }

  @override
  Future<dynamic> delete(int id) {
    caches.removeWhere((object) => object.id == id);
    return Future.value(id);
  }

  @override
  Future deleteAll(Iterable<int> ids) {
    caches.removeWhere((object) => ids.contains(object.id));
    return Future.value();
  }

  @override
  Future<CacheObject> get(String url) {
    return Future.value(caches.firstWhere(
      (object) => object.url == url,
      orElse: () => null,
    ));
  }

  @override
  Future<List<CacheObject>> getAllObjects() {
    return Future.value(List.unmodifiable(caches));
  }

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) {
    // unsuppported in this provider
    return Future.value([]);
  }

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) {
    // unsuppported in this provider
    return Future.value([]);
  }

  @override
  Future<CacheObject> insert(CacheObject cacheObject) {
    cacheObject.id = caches.length;
    caches.add(cacheObject);
    return Future.value(cacheObject);
  }

  @override
  Future<int> update(CacheObject cacheObject) {
    caches[cacheObject.id] = cacheObject;
    return Future.value(cacheObject.id);
  }
}
