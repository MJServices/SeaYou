import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:seayou_app/services/upload_controller.dart';
import 'package:seayou_app/services/upload_service.dart';

Future<UploadResult?> fakeUploader({required String bucket, required String userId, required File file, required String prefix}) async {
  await Future.delayed(const Duration(milliseconds: 50));
  return UploadResult(bucket: bucket, path: '$userId/${prefix}_1.jpg', url: 'http://example.com/$userId/${prefix}_1.jpg');
}

void main() {
  test('UploadController processes queue with concurrency', () async {
    final c = UploadController(concurrency: 2, uploader: fakeUploader);
    final tasks = List.generate(5, (i) => UploadTask(id: '$i', bucket: 'test', userId: 'u', file: File('C:/tmp/p$i.jpg'), prefix: 'p'));
    for (final t in tasks) {
      await c.enqueue(t);
    }
    await Future.delayed(const Duration(milliseconds: 400));
    final allDone = c.statuses.values.every((s) => s.completed);
    expect(allDone, true);
  });
}
