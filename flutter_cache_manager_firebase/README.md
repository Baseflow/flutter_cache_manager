# flutter_cache_manager_firebase

A Firebase implementation for [flutter_cache_manager](https://pub.dev/packages/flutter_cache_manager)

## Getting Started

This library contains FirebaseCacheManager and FirebaseHttpFileService.

You can easily fetch a file stored on Firebase with 
```dart
var file = await FirebaseCacheManager().getSingleFile(url);
```

You could also write your own CacheManager which uses the FirebaseHttpFileService.