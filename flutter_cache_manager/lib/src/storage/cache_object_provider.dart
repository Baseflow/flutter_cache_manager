import 'package:flutter_cache_manager/src/storage/cache_info_repository.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:sqflite/sqflite.dart';

const _tableCacheObject = 'cacheObject';

class CacheObjectProvider implements CacheInfoRepository {
  Database db;
  String path;

  CacheObjectProvider(this.path);

  @override
  Future open() async {
    db = await openDatabase(path, version: 3,
        onCreate: (Database db, int version) async {
      await db.execute('''
      create table $_tableCacheObject ( 
        ${CacheObject.columnId} integer primary key, 
        ${CacheObject.columnUrl} text, 
        ${CacheObject.columnKey} text, 
        ${CacheObject.columnPath} text,
        ${CacheObject.columnETag} text,
        ${CacheObject.columnValidTill} integer,
        ${CacheObject.columnTouched} integer,
        ${CacheObject.columnLength} integer
        );
        create unique index $_tableCacheObject${CacheObject.columnKey} 
        ON $_tableCacheObject (${CacheObject.columnKey});
      ''');
    }, onUpgrade: (Database db, int oldVersion, int newVersion) async {
      // Migration for adding the optional key, does the following:
      // Adds the new column
      // Creates a unique index for the column
      // Migrates over any existing URLs to keys
      if (oldVersion <= 1) {
        var hasKeyColumn = await _hasColumnName(db, CacheObject.columnKey);

        await db.transaction((txn) async {
          if (!hasKeyColumn) {
            await txn.execute('''
            alter table $_tableCacheObject 
            add ${CacheObject.columnKey} text;
            ''');
          }
          await txn.execute('''
            update $_tableCacheObject 
              set ${CacheObject.columnKey} = ${CacheObject.columnUrl}
              where ${CacheObject.columnKey} is null;
            ''');
          if (!hasKeyColumn) {
            await txn.execute('''
            create index $_tableCacheObject${CacheObject.columnKey} 
              on $_tableCacheObject (${CacheObject.columnKey});
            ''');
          }
        });
      }
      if (oldVersion <= 2) {
        var hasLengthColumn =
            await _hasColumnName(db, CacheObject.columnLength);

        if (!hasLengthColumn) {
          await db.execute('''
        alter table $_tableCacheObject 
        add ${CacheObject.columnLength} integer;
        ''');
        }
      }
    });
  }

  @override
  Future<dynamic> updateOrInsert(CacheObject cacheObject) {
    if (cacheObject.id == null) {
      return insert(cacheObject);
    } else {
      return update(cacheObject);
    }
  }

  @override
  Future<CacheObject> insert(CacheObject cacheObject) async {
    var id = await db.insert(_tableCacheObject, cacheObject.toMap());
    return cacheObject.copyWith(id: id);
  }

  @override
  Future<CacheObject> get(String key) async {
    List<Map> maps = await db.query(_tableCacheObject,
        columns: null, where: '${CacheObject.columnKey} = ?', whereArgs: [key]);
    if (maps.isNotEmpty) {
      return CacheObject.fromMap(maps.first.cast<String, dynamic>());
    }
    return null;
  }

  @override
  Future<int> delete(int id) {
    return db.delete(_tableCacheObject,
        where: '${CacheObject.columnId} = ?', whereArgs: [id]);
  }

  @override
  Future deleteAll(Iterable<int> ids) {
    return db.delete(_tableCacheObject,
        where: '${CacheObject.columnId} IN (' + ids.join(',') + ')');
  }

  @override
  Future<int> update(CacheObject cacheObject) {
    return db.update(_tableCacheObject, cacheObject.toMap(),
        where: '${CacheObject.columnId} = ?', whereArgs: [cacheObject.id]);
  }

  @override
  Future<List<CacheObject>> getAllObjects() async {
    return CacheObject.fromMapList(
      await db.query(_tableCacheObject, columns: null),
    );
  }

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) async {
    return CacheObject.fromMapList(await db.query(
      _tableCacheObject,
      columns: null,
      orderBy: '${CacheObject.columnTouched} DESC',
      where: '${CacheObject.columnTouched} < ?',
      whereArgs: [
        DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch
      ],
      limit: 100,
      offset: capacity,
    ));
  }

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) async {
    return CacheObject.fromMapList(await db.query(
      _tableCacheObject,
      where: '${CacheObject.columnTouched} < ?',
      columns: null,
      whereArgs: [DateTime.now().subtract(maxAge).millisecondsSinceEpoch],
      limit: 100,
    ));
  }

  @override
  Future close() => db.close();

  Future<bool> _hasColumnName(Database db, String columnName) async {
    var query = await db.rawQuery('''
          SELECT COUNT(*) AS CNTREC FROM pragma_table_info('$_tableCacheObject') WHERE 
          name='$columnName';
          ''');
    return query.first.cast<String, int>()['CNTREC'] > 0;
  }
}
