# flutter_cache_manager

[![pub package](https://img.shields.io/pub/v/flutter_cache_manager.svg)](https://pub.dartlang.org/packages/flutter_cache_manager)
[![Build Status](https://app.bitrise.io/app/b3454de795b5c22a/status.svg?token=vEfW1ztZ-tkoUx64yXeklg&branch=master)](https://app.bitrise.io/app/b3454de795b5c22a)

A CacheManager to download and cache files in the cache directory of the app. Various settings on how long to keep a file can be changed.

It uses the cache-control http header to efficiently retrieve files.

The more basic usage is explained here. See the complete docs for more info.

## Usage

The cache manager can be used to get a file on various ways
The easiest way to get a single file is call `.getSingleFile`.

```
    var file = await DefaultCacheManager().getSingleFile(url);
```
`getFile(url)` returns a stream with the first result being the cached file and later optionally the downloaded file.

`downloadFile(url)` directly downloads from the web.

`getFileFromCache` only retrieves from cache and returns no file when the file is not in the cache.


`putFile` gives the option to put a new file into the cache without downloading it.

`removeFile` removes a file from the cache. 

`emptyCache` removes all files from the cache. 


## Settings
The cache manager is customizable by extending the BaseCacheManager.
Below is an example with other settings for the maximum age of files, maximum number of objects
and a custom http getter. The key parameter in the constructor and the getFilePath method are mandatory.

```

class CustomCacheManager extends BaseCacheManager {
  static const key = "customCache";

  static CustomCacheManager _instance;

  factory CustomCacheManager() {
    if (_instance == null) {
      _instance = new CustomCacheManager._();
    }
    return _instance;
  }

  CustomCacheManager._() : super(key,
      maxAgeCacheObject: Duration(days: 7),
      maxNrOfCacheObjects: 20,
      fileFetcher: _customHttpGetter);

  Future<String> getFilePath() async {
    var directory = await getTemporaryDirectory();
    return p.join(directory.path, key);
  }

  static Future<FileFetcherResponse> _customHttpGetter(String url, {Map<String, String> headers}) async {
    // Do things with headers, the url or whatever.
    return HttpFileFetcherResponse(await http.get(url, headers: headers));
  }
}

```

## How it works
By default the cached files are stored in the temporary directory of the app. This means the OS can delete the files any time.

Information about the files is stored in a database using sqflite. The file name of the database is the key of the cacheManager, that's why that has to be unique.

This cache information contains the end date till when the file is valid and the eTag to use with the http cache-control.
