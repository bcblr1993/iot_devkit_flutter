import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/utils/isolate_worker.dart';

void main() {
  group('recommendedIsolateWorkerCount', () {
    test('leaves one core for a single process main isolate', () {
      expect(
        recommendedIsolateWorkerCount(processorCount: 10),
        9,
      );
    });

    test('shares the worker budget across two process shards', () {
      expect(
        recommendedIsolateWorkerCount(
          processorCount: 10,
          processCount: 2,
        ),
        4,
      );
    });

    test('keeps at least one worker and caps very large hosts', () {
      expect(
        recommendedIsolateWorkerCount(
          processorCount: 4,
          processCount: 8,
        ),
        1,
      );
      expect(
        recommendedIsolateWorkerCount(processorCount: 128),
        12,
      );
    });
  });
}
