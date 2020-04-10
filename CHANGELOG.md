## [1.2.0] - 2020-04-10
* Added getFileStream to CacheManager
    * getFileStream has an optional parameter 'withProgress' to receive progress.
    * getFileStream returns a FileResponse which is either a FileInfo or a DownloadProgress.
* Changes to FileFetcher and FileFetcherResponse:
    * FileFetcher is now replaced with a FileService which is a class instead of a function.
    * FileServiceResponse doesn't just give magic headers, but concrete implementation of the needed information.
    * FileServiceResponse gives a contentStream instead of content for more efficient handling of the data.
    * FileServiceResponse contains contentLength with information about the total size of the content.
* Changes in CacheStore for testability:
    * CleanupRunMinInterval can now be set.
    * Expects a mockable directory instead of a path.
* Added CacheInfoRepository interface to possibly replace the current CacheObjectProvider based on sqflite.
* Changes in WebHelper
  * Files are now always saved with a new name. Files are first saved to storage before old file is removed.
* General code quality improvements

## [1.1.3] - 2019-10-17
* Use try-catch in WebHelper so VM understands that errors are not uncaught.

## [1.1.2] - 2019-10-16

* Better error handling (really better this time).
* Fix that oldest files are removed, and not the newest.
* Fix error when cache data exists, but file is already removed.
* await on putFile

## [1.1.1] - 2019-07-23

* Changed error handling back to throwing the error as it is supposed to be.

## [1.1.0] - 2019-07-13

* New method to get fileinfo from memory.
* Better error handling.

## [1.0.0] - 2019-06-27

* Keep SQL connection open during session.
* Update dependencies

## [0.3.2] - 2019-03-06

* Fixed image loading after loading failed once.

## [0.3.1] - 2019-02-27

* Added method to clear cache

## [0.3.0] - 2019-02-18

* Complete refactor of library
* Use of SQFlite instead of shared preferences for cache info
* Added the option to use a custom file fetcher (for example for firebase)
* Support for AndroidX

## [0.2.0] - 2018-10-13

* Fixed library compatibility issue

## [0.1.2] - 2018-08-30

* Fixed library compatibility issue
* Improved some synchronization

## [0.1.1] - 2018-04-27

* Fixed some issues when file could not be downloaded the first time it is trying to be retrieved.

## [0.1.0] - 2018-04-14

* Fixed ConcurrentModificationError in cache cleaning
* Added optional headers
* Moved to Dart 2.0

## [0.0.4+1] - 2018-02-16

* Fixed nullpointer when non-updated file (a 304 response) has no cache-control period. 

## [0.0.4] - 2018-01-31

* Fixed issues with cache cleaning

## [0.0.3] - 2018-01-08

* Fixed relative paths on iOS.

## [0.0.2] - 2017-12-29

* Did some refactoring and made a useful readme.

## [0.0.1] - 2017-12-28

* Extracted the cache manager from cached_network_image
