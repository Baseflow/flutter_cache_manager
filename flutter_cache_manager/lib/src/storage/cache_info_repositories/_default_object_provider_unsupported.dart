import 'package:flutter_cache_manager/src/storage/cache_object.dart';

import 'default_object_provider.dart' as shared;

class DefaultObjectProvider implements shared.DefaultObjectProvider {
  DefaultObjectProvider();

  @override
  Future close() {
    throw UnsupportedError('Platform is not supported');
  }

  @override
  Future<int> delete(int id) {
    throw UnsupportedError('Platform is not supported');
  }

  @override
  Future deleteAll(Iterable<int> ids) {
    throw UnsupportedError('Platform is not supported');
  }

  @override
  Future<CacheObject> get(String url) {
    throw UnsupportedError('Platform is not supported');
  }

  @override
  Future<List<CacheObject>> getAllObjects() {
    throw UnsupportedError('Platform is not supported');
  }

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) {
    throw UnsupportedError('Platform is not supported');
  }

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) {
    throw UnsupportedError('Platform is not supported');
  }

  @override
  Future<CacheObject> insert(CacheObject cacheObject) {
    throw UnsupportedError('Platform is not supported');
  }

  @override
  Future open() {
    throw UnsupportedError('Platform is not supported');
  }

  @override
  Future<int> update(CacheObject cacheObject) {
    throw UnimplementedError();
  }

  @override
  Future updateOrInsert(CacheObject cacheObject) {
    throw UnsupportedError('Platform is not supported');
  }
}
