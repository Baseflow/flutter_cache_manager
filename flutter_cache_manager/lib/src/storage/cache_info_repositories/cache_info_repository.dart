import 'dart:async';

import 'package:flutter_cache_manager/src/storage/cache_object.dart';

/// Base class for cache info repositories
abstract class CacheInfoRepository {
  /// Opens the repository
  Future open();

  /// Updates a given [CacheObject], if it exists, or adds a new item to the repository
  Future<dynamic> updateOrInsert(CacheObject cacheObject);

  /// Inserts [cacheObject] into the repository
  Future<CacheObject> insert(CacheObject cacheObject);

  /// Gets a [CacheObject] by [key]
  Future<CacheObject> get(String key);

  /// Deletes a cache object by [id]
  Future<int> delete(int id);

  /// Deletes items with [ids] from the repository
  Future<int> deleteAll(Iterable<int> ids);

  /// Updates an existing [cacheObject]
  Future<int> update(CacheObject cacheObject);

  /// Gets the list of all objects in the cache
  Future<List<CacheObject>> getAllObjects();

  /// Gets the list of [CacheObject] that can be removed if the repository is over capacity.
  ///
  /// The exact implementation is up to the repository, but implementations should
  /// return a preferred list of items. For example, the least recently accessed
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity);

  /// Returns a list of [CacheObject] that are older than [maxAge]
  Future<List<CacheObject>> getOldObjects(Duration maxAge);

  /// Close the connection to the repository
  Future close();
}
