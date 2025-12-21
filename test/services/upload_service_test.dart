import 'package:flutter_test/flutter_test.dart';
import 'package:seayou_app/services/upload_service.dart';

void main() {
  test('UploadService buildPath format', () {
    final path = UploadService.buildPath(userId: 'user123', prefix: 'avatar', ext: 'jpg');
    expect(path.startsWith('user123/avatar_'), true);
    expect(path.endsWith('.jpg'), true);
  });
}
