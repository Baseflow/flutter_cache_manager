import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/json_cache_info_repository.dart';

void main() {
  group('JsonCacheInfoRepository', () {
    test('handles empty file gracefully', () async {
      // Create a temporary file
      final tempFile = File('${Directory.systemTemp.path}/test_empty.json');
      await tempFile.create();

      // Ensure the file is empty
      expect(await tempFile.length(), 0);

      // Initialize the repository
      final repository = JsonCacheInfoRepository.withFile(tempFile);

      // Call the method to test
      await repository.open();

      // Verify no exceptions are thrown and repository is empty
      expect(await repository.getAllObjects(), isEmpty);

      // Clean up
      await tempFile.delete();
    });
  });
}