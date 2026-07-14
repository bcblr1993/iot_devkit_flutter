class DeviceShardRange {
  final int start;
  final int end;

  const DeviceShardRange(this.start, this.end);

  bool get isEmpty => end < start;
  int get count => isEmpty ? 0 : end - start + 1;
}

/// Splits one configured device range across multiple application processes.
///
/// The CLI uses one-based notation (`--shard=1/2`), while [index] remains
/// zero-based internally. Every original device number belongs to exactly one
/// shard, so client IDs and credentials keep their configured suffixes without
/// overlapping across processes.
class ProcessShard {
  final int index;
  final int count;

  const ProcessShard({this.index = 0, this.count = 1})
      : assert(count > 0),
        assert(index >= 0 && index < count);

  static const ProcessShard single = ProcessShard();

  bool get isSharded => count > 1;
  String get label => '${index + 1}/$count';

  /// Parses `--shard=N/M` and rejects malformed shard values.
  ///
  /// Silently falling back to a single process would be dangerous here: a typo
  /// in one of two launch commands would make that process connect the entire
  /// device range and overlap the other shard's MQTT client IDs.
  factory ProcessShard.fromArguments(Iterable<String> arguments) {
    ProcessShard? parsed;
    for (final argument in arguments) {
      if (!argument.startsWith('--shard=')) continue;
      if (parsed != null) {
        throw const FormatException('--shard may only be specified once.');
      }
      final value = argument.substring('--shard='.length);
      final parts = value.split('/');
      if (parts.length != 2) {
        throw FormatException('Invalid shard "$value"; expected N/M.');
      }

      final oneBasedIndex = int.tryParse(parts[0]);
      final shardCount = int.tryParse(parts[1]);
      if (oneBasedIndex == null ||
          shardCount == null ||
          shardCount < 1 ||
          oneBasedIndex < 1 ||
          oneBasedIndex > shardCount) {
        throw FormatException(
          'Invalid shard "$value"; N and M must satisfy 1 <= N <= M.',
        );
      }
      parsed = ProcessShard(index: oneBasedIndex - 1, count: shardCount);
    }
    return parsed ?? single;
  }

  /// Returns this process's contiguous slice of the inclusive [start]..[end]
  /// range. Remainders are assigned to the earliest shards, keeping shard sizes
  /// within one device of each other.
  DeviceShardRange slice(int start, int end) {
    if (end < start) return DeviceShardRange(start, start - 1);

    final total = end - start + 1;
    final baseSize = total ~/ count;
    final remainder = total % count;
    final localSize = baseSize + (index < remainder ? 1 : 0);
    final precedingRemainder = index < remainder ? index : remainder;
    final localStart = start + (index * baseSize) + precedingRemainder;
    return DeviceShardRange(localStart, localStart + localSize - 1);
  }
}
