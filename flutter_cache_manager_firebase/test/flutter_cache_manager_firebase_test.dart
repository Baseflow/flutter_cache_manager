import 'package:flutter_cache_manager_firebase/flutter_cache_manager_firebase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FirebaseCacheManager key is set', () {
    expect(FirebaseCacheManager.key, 'firebaseCache');
  });
}
