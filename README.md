# flutter_cache_manager

[![pub package](https://img.shields.io/pub/v/flutter_cache_manager.svg)](https://pub.dartlang.org/packages/flutter_cache_manager)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.me/renefloor)

A CacheManager to download and cache files in the cache directory of the app. Various settings on how long to keep a file can be changed.

It uses the cache-control http header to efficiently retrieve files.

## Usage

```
    var cacheManager = await CacheManager.getInstance();
    var file = await cacheManager.getFile(url);
```


## Settings
Some settings of the CacheManager can be changed.
All these preferences are statics and should be set before the first use of the CacheManager, so preferably directly on start of your app.

For extra logging set:
```
  CacheManager.showDebugLogs = true;
```

The cache can be cleaned after it is used to get a file. By default this happens once every week. You can change this by setting `inBetweenCleans`. 
```
  CacheManager.inBetweenCleans = new Duration(days: 7);
```

The CacheManager checks for two things, for objects that are too old and the size of the cache.

By default it removes objects that haven't been used for 30 days. Set this by `maxAgeCacheObject`. *This is not about when the object is first downloaded, but when it is used the last.
```
  CacheManager.maxAgeCacheObject = new Duration(days: 30);
```

By default the cache size is set to 200, when the cache grows beyond this it will remove the oldest objects again by when last used. Set this with `maxNrOfCacheObjects`.
```
  CacheManager.maxNrOfCacheObjects = 200;
```

## How it works
The cached files are stored in the temporary directory of the app. This means the OS can delete the files any time.

Information about the files is stored in the shared preferences with the key "lib_cached_image_data". (Because images was the first use of this library :)) The date when the cache is last cleaned is stored as "lib_cached_image_data_last_clean".

This cache information contains the end date till when the file is valid and the eTag to use with the http cache-control.
