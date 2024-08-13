import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:retry/retry.dart';

/// [FirebaseHttpFileService] is another common file service which parses a
/// firebase reference into, to standard url which can be passed to the
/// standard [HttpFileService].
class FirebaseHttpFileService extends HttpFileService {
  final RetryOptions? retryOptions;

  FirebaseHttpFileService({
    this.retryOptions,
    this.bucket,
  }) : super();

  final String? bucket;

  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers}) async {
    late Reference ref;
    if (bucket != null) {
      ref =
          FirebaseStorage.instanceFor(bucket: "gs://$bucket").ref().child(url);
    } else {
      ref = FirebaseStorage.instance.ref().child(url);
    }

    String downloadUrl;
    if (retryOptions != null) {
      downloadUrl = await retryOptions!.retry(
        () async => await ref.getDownloadURL(),
        retryIf: (e) => e is FirebaseException,
      );
    } else {
      downloadUrl = await ref.getDownloadURL();
    }
    return super.get(downloadUrl);
  }
}
