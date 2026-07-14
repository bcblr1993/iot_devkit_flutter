import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/process_shard.dart';

void main() {
  group('ProcessShard arguments', () {
    test('defaults to a single process', () {
      final shard = ProcessShard.fromArguments(const []);

      expect(shard.index, 0);
      expect(shard.count, 1);
      expect(shard.isSharded, isFalse);
    });

    test('parses one-based shard notation', () {
      final shard = ProcessShard.fromArguments(const ['--shard=2/3']);

      expect(shard.index, 1);
      expect(shard.count, 3);
      expect(shard.label, '2/3');
    });

    test('rejects invalid notation to prevent overlapping clients', () {
      expect(
        () => ProcessShard.fromArguments(const ['--shard=0/2']),
        throwsFormatException,
      );
      expect(
        () => ProcessShard.fromArguments(const ['--shard=3/2']),
        throwsFormatException,
      );
      expect(
        () => ProcessShard.fromArguments(const ['--shard=abc']),
        throwsFormatException,
      );
      expect(
        () => ProcessShard.fromArguments(
          const ['--shard=1/2', '--shard=2/2'],
        ),
        throwsFormatException,
      );
    });
  });

  group('ProcessShard range slicing', () {
    test('splits 2000 devices into two non-overlapping ranges', () {
      const first = ProcessShard(index: 0, count: 2);
      const second = ProcessShard(index: 1, count: 2);

      expect(first.slice(1, 2000).start, 1);
      expect(first.slice(1, 2000).end, 1000);
      expect(second.slice(1, 2000).start, 1001);
      expect(second.slice(1, 2000).end, 2000);
    });

    test('distributes remainders without gaps or overlap', () {
      final ranges = [
        for (var i = 0; i < 3; i++)
          ProcessShard(index: i, count: 3).slice(10, 19),
      ];

      expect(ranges.map((range) => range.count), [4, 3, 3]);
      expect(ranges.map((range) => range.start), [10, 14, 17]);
      expect(ranges.map((range) => range.end), [13, 16, 19]);
    });

    test('allows empty slices when there are more shards than devices', () {
      const shard = ProcessShard(index: 3, count: 4);
      final range = shard.slice(1, 2);

      expect(range.isEmpty, isTrue);
      expect(range.count, 0);
    });
  });
}
