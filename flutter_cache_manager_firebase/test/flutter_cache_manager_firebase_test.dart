import 'dart:io';

import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_cache_manager_firebase/flutter_cache_manager_firebase.dart';
import 'package:flutter_test/flutter_test.dart';

final filename = 'someimage.png';

void main() {
  test('Opens a file', () async {
    final storage = MockFirebaseStorage();
    final storageRef = storage.ref().child(filename);
    final image = File(filename);
    final task = storageRef.putFile(image);
    await task.whenComplete(() {});
    final cacheManager = FirebaseCacheManager();
    print(storageRef.fullPath);

    cacheManager.downloadFile(storageRef.fullPath);

    storageRef.getData();
  });
}
