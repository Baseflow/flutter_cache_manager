<b>BREAKING CHANGES IN V2</b>

CacheManager v2 introduced some breaking changes when configuring a custom CacheManager. [See the bottom of this page
 for the changes.](#breaking-changes-in-v2)

# flutter_cache_manager

[![pub package](https://img.shields.io/pub/v/flutter_cache_manager.svg)](https://pub.dartlang.org/packages/flutter_cache_manager)
[![Build Status](https://app.bitrise.io/app/b3454de795b5c22a/status.svg?token=vEfW1ztZ-tkoUx64yXeklg&branch=master)](https://app.bitrise.io/app/b3454de795b5c22a)
[![codecov](https://codecov.io/gh/Baseflow/flutter_cache_manager/branch/master/graph/badge.svg)](https://codecov.io/gh/Baseflow/flutter_cache_manager)

A CacheManager to download and cache files in the cache directory of the app. Various settings on how long to keep a file can be changed.

It uses the cache-control http header to efficiently retrieve files.

The more basic usage is explained here. See the complete docs for more info.


## Usage

The cache manager can be used to get a file on various ways
The easiest way to get a single file is call `.getSingleFile`.

```
    var file = await DefaultCacheManager().getSingleFile(url);
```
`getFileStream(url)` returns a stream with the first result being the cached file and later optionally the downloaded file.

`getFileStream(url, withProgress: true)` when you set withProgress on true, this stream will also emit DownloadProgress when the file is not found in the cache.

`downloadFile(url)` directly downloads from the web.

`getFileFromCache` only retrieves from cache and returns no file when the file is not in the cache.


`putFile` gives the option to put a new file into the cache without downloading it.

`removeFile` removes a file from the cache. 

`emptyCache` removes all files from the cache. 

## Other implementations
When your files are stored on Firebase Storage you can use [flutter_cache_manager_firebase](https://pub.dev/packages/flutter_cache_manager_firebase).

## Customize
The cache manager is customizable by creating a new CacheManager. It is very important to not create more than 1
 CacheManager instance with the same key as these bite each other. In the example down here the manager is created as a 
 Singleton, but you could also use for example Provider to Provide a CacheManager on the top level of your app.
Below is an example with other settings for the maximum age of files, maximum number of objects
and a custom FileService. The key parameter in the constructor is mandatory, all other variables are optional.

```
class CustomCacheManager {
  static const key = 'customCacheKey';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 20,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileSystem: IOFileSystem(key),
      fileService: HttpFileService(),
    ),
  );
}
```

## How it works
By default the cached files are stored in the temporary directory of the app. This means the OS can delete the files any time.

Information about the files is stored in a database using sqflite. The file name of the database is the key of the cacheManager, that's why that has to be unique.

This cache information contains the end date till when the file is valid and the eTag to use with the http cache-control.

## Breaking changes in v2
- There is no longer a need to extend on BaseCacheManager, you can directly call the constructor. The BaseCacheManager
 is therefore renamed to CacheManager as it is not really just a 'base' anymore.

- The constructor now expects a Config object with some settings you were used to, but some are slightly different.
For example the system where you want to store your files is not just a dictionary anymore, but a FileSystem. That way
you have more freedom on where to store your files.
