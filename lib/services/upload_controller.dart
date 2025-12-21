import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'upload_service.dart';
import 'dart:collection';

class UploadTask {
  final String id;
  final String bucket;
  final String userId;
  final File file;
  final String prefix;
  final Completer<UploadStatus> completer = Completer<UploadStatus>();
  UploadTask({required this.id, required this.bucket, required this.userId, required this.file, required this.prefix});
}

class UploadStatus {
  final String id;
  final bool started;
  final bool completed;
  final bool failed;
  final double progress;
  final String? url;
  const UploadStatus({required this.id, this.started = false, this.completed = false, this.failed = false, this.progress = 0.0, this.url});
}

typedef UploaderFn = Future<UploadResult?> Function({required String bucket, required String userId, required File file, required String prefix});

class UploadController extends ChangeNotifier {
  final int concurrency;
  final UploaderFn uploader;
  final Queue<UploadTask> _queue = Queue<UploadTask>();
  final Map<String, UploadStatus> _statuses = {};
  int _running = 0;

  UploadController({this.concurrency = 3, UploaderFn? uploader}) : uploader = uploader ?? (({required String bucket, required String userId, required File file, required String prefix}) => UploadService().uploadFile(bucket: bucket, userId: userId, file: file, prefix: prefix));

  Map<String, UploadStatus> get statuses => Map.unmodifiable(_statuses);

  Future<UploadStatus> enqueue(UploadTask task) async {
    _statuses[task.id] = UploadStatus(id: task.id, started: false, completed: false, failed: false, progress: 0.0);
    _queue.add(task);
    _pump();
    notifyListeners();
    // Wait for upload to complete
    return await task.completer.future;
  }

  void _pump() {
    while (_running < concurrency && _queue.isNotEmpty) {
      final task = _queue.removeFirst();
      _running += 1;
      _statuses[task.id] = UploadStatus(id: task.id, started: true, completed: false, failed: false, progress: 0.1);
      notifyListeners();
      uploader(bucket: task.bucket, userId: task.userId, file: task.file, prefix: task.prefix).then((res) {
        final status = UploadStatus(id: task.id, started: true, completed: res != null, failed: res == null, progress: 1.0, url: res?.url);
        _statuses[task.id] = status;
        task.completer.complete(status); // Complete the future
      }).catchError((err) {
        final status = UploadStatus(id: task.id, started: true, completed: false, failed: true, progress: 0.0);
        _statuses[task.id] = status;
        task.completer.complete(status); // Complete with error status
      }).whenComplete(() {
        _running -= 1;
        notifyListeners();
        _pump();
      });
    }
  }
}
