# flutter_cache_manager

[![pub package](https://img.shields.io/pub/v/flutter_cache_manager.svg)](https://pub.dartlang.org/packages/flutter_cache_manager)

*WORK IN PROGRESS*

Cache manager extracted from [Cached Network Image](https://pub.dartlang.org/packages/cached_network_image)

## Usage

```
    var cacheManager = await CacheManager.getInstance();
    var file = await cacheManager.getFile(url);
```