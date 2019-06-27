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
