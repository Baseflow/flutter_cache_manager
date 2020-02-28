import 'dart:async';

import 'package:flutter_cache_manager/src/storage/cache_object.dart';

abstract class CacheInfoRepository{

  Future open();

  Future<dynamic> updateOrInsert(CacheObject cacheObject);

  Future<CacheObject> insert(CacheObject cacheObject) ;

  Future<CacheObject> get(String url);

  Future<int> delete(int id);

  Future deleteAll(Iterable<int> ids) ;

  Future<int> update(CacheObject cacheObject);

  Future<List<CacheObject>> getAllObjects();

  Future<List<CacheObject>> getObjectsOverCapacity(int capacity);

  Future<List<CacheObject>> getOldObjects(Duration maxAge);

  Future close();
}