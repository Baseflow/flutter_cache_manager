import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image/image.dart';

const supportedFileNames = ['jpg', 'jpeg', 'png', 'tga', 'gif', 'cur', 'ico'];
mixin ImageCacheManager on BaseCacheManager {

  Future<FileInfo> _resizeImageFile(
    FileInfo originalFile,
    String key,
    int maxWidth,
    int maxHeight,
  ) async {
    var originalFileName = originalFile.file.path;
    var fileExtension = originalFileName.split('.').last;
    if(!supportedFileNames.contains(fileExtension)){
      return originalFile;
    }

    var image = decodeImage(await originalFile.file.readAsBytes());
    if (maxWidth != null && maxHeight != null) {
      var resizeFactorWidth = image.width/maxWidth;
      var resizeFactorHeight = image.height/maxHeight;
      var resizeFactor = max(resizeFactorHeight, resizeFactorWidth);

      maxWidth = (image.width / resizeFactor) as int;
      maxHeight = (image.height / resizeFactor) as int;
    }

    var resized = copyResize(image, width: maxWidth, height: maxHeight);
    var resizedFile = encodeNamedImage(resized, originalFileName);
    var maxAge = originalFile.validTill.difference(DateTime.now());

    var file = await putFile(
      originalFile.originalUrl,
      Uint8List.fromList(resizedFile),
      key: key,
      maxAge: maxAge,
      fileExtension: fileExtension,
    );

    return FileInfo(
      file,
      originalFile.source,
      originalFile.validTill,
      originalFile.originalUrl,
    );
  }

  Stream<FileResponse> _fetchedResizedFile(
    String url,
    String originalKey,
    String resizedKey,
    Map<String, String> headers,
    bool withProgress, {
    int maxWidth,
    int maxHeight,
  }) async* {
    await for (var response in getFileStream(
      url,
      key: originalKey,
      headers: headers,
      withProgress: withProgress,
    )) {
      if (response is DownloadProgress) {
        yield response;
      }
      if (response is FileInfo) {
        yield await _resizeImageFile(
          response,
          resizedKey,
          maxWidth,
          maxHeight,
        );
      }
    }
  }

  final Map<String, Stream<FileResponse>> _runningResizes = {};
  Stream<FileResponse> getImageFile(
    String url, {
    String key,
    Map<String, String> headers,
    bool withProgress,
    int maxHeight,
    int maxWidth,
  }) async* {
    if (maxHeight == null && maxWidth == null) {
      yield* getFileStream(url,
          key: key, headers: headers, withProgress: withProgress);
      return;
    }
    key ??= url;
    var resizedKey = 'resized';
    if (maxWidth != null) resizedKey += '_w$maxWidth';
    if (maxHeight != null) resizedKey += '_h$maxHeight';
    resizedKey += '_$key';

    var fromCache = await getFileFromCache(resizedKey);
    if (fromCache != null) {
      yield fromCache;
      if (fromCache.validTill.isAfter(DateTime.now())) {
        return;
      }
      withProgress = false;
    }
    if (!_runningResizes.containsKey(resizedKey)) {
      _runningResizes[resizedKey] = _fetchedResizedFile(
        url,
        key,
        resizedKey,
        headers,
        withProgress,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
    }
    yield* _runningResizes[resizedKey];
  }
}
