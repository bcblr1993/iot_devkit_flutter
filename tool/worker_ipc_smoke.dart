import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _ipcPrefix = 'IOT_DEVKIT_IPC ';
const _timeout = Duration(seconds: 20);

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart tool/worker_ipc_smoke.dart <executable>');
    exitCode = 64;
    return;
  }

  final executable = File(arguments.single);
  if (!executable.existsSync()) {
    stderr.writeln('Worker executable not found: ${executable.path}');
    exitCode = 66;
    return;
  }

  Process? process;
  StreamSubscription<String>? stdoutSubscription;
  StreamSubscription<String>? stderrSubscription;
  final hello = Completer<void>();
  final accepted = Completer<void>();
  final activeStatus = Completer<void>();
  final stopped = Completer<void>();
  final fatal = Completer<String>();
  final events = <String>[];
  final workerErrors = <String>[];

  try {
    process = await Process.start(
      executable.path,
      const ['--worker', '--shard=1/2', '--performance'],
    );

    stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (!line.startsWith(_ipcPrefix)) return;
        try {
          final decoded = jsonDecode(line.substring(_ipcPrefix.length));
          if (decoded is! Map) {
            throw const FormatException('IPC payload is not an object');
          }
          final message = Map<String, dynamic>.from(decoded);
          final type = message['type']?.toString() ?? 'unknown';
          events.add(type);
          switch (type) {
            case 'hello':
              if (!hello.isCompleted) hello.complete();
              break;
            case 'accepted':
              if (!accepted.isCompleted) accepted.complete();
              break;
            case 'status':
              final state = message['state']?.toString();
              if (state != null &&
                  state != 'idle' &&
                  state != 'failed' &&
                  !activeStatus.isCompleted) {
                activeStatus.complete();
              }
              break;
            case 'stopped':
              if (!stopped.isCompleted) stopped.complete();
              break;
            case 'fatal':
              if (!fatal.isCompleted) {
                fatal.complete(message['error']?.toString() ?? 'unknown fatal');
              }
              break;
          }
        } catch (error) {
          if (!fatal.isCompleted) fatal.complete('Invalid IPC output: $error');
        }
      },
      onError: (Object error) {
        if (!fatal.isCompleted) fatal.complete('stdout failed: $error');
      },
      onDone: () {
        if (!stopped.isCompleted && !fatal.isCompleted) {
          fatal.complete('stdout closed before stopped');
        }
      },
    );

    stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(workerErrors.add);

    unawaited(process.exitCode.then((code) {
      if (!stopped.isCompleted && !fatal.isCompleted) {
        fatal.complete('worker exited early with code $code');
      }
    }));

    await _waitFor(hello.future, fatal.future, 'hello');
    process.stdin.writeln('$_ipcPrefix${jsonEncode({
          'type': 'start',
          'config': _smokeConfig(),
        })}');
    await process.stdin.flush();

    await _waitFor(accepted.future, fatal.future, 'accepted');
    await _waitFor(activeStatus.future, fatal.future, 'active status');

    process.stdin.writeln('$_ipcPrefix${jsonEncode(const {'type': 'stop'})}');
    await process.stdin.flush();
    await _waitFor(stopped.future, fatal.future, 'stopped');
    await process.stdin.close();

    final code = await process.exitCode.timeout(_timeout);
    if (code != 0) {
      throw StateError('worker exited with code $code');
    }

    stdout.writeln(jsonEncode({
      'passed': true,
      'exitCode': code,
      'events': events,
    }));
  } catch (error, stack) {
    stderr.writeln('Worker IPC smoke failed: $error');
    if (workerErrors.isNotEmpty) {
      stderr.writeln('Worker stderr:\n${workerErrors.join('\n')}');
    }
    stderr.writeln(stack);
    process?.kill();
    exitCode = 1;
  } finally {
    try {
      await process?.stdin.close();
    } catch (_) {
      // The worker may already have closed its anonymous input pipe.
    }
    await stdoutSubscription?.cancel();
    await stderrSubscription?.cancel();
  }
}

Future<void> _waitFor(
  Future<void> expected,
  Future<String> fatal,
  String label,
) async {
  await Future.any<void>([
    expected,
    fatal.then<void>((message) => throw StateError(message)),
  ]).timeout(_timeout, onTimeout: () {
    throw TimeoutException('Timed out waiting for $label', _timeout);
  });
}

Map<String, dynamic> _smokeConfig() {
  return {
    'mode': 'advanced',
    'mqtt': {
      'host': '127.0.0.1',
      'port': 65534,
      'topic': 'v1/devices/me/telemetry',
      'qos': 0,
      'protocol_version': 'mqtt_3_1_1',
      'enable_ssl': false,
    },
    'groups': [
      {
        'id': 'worker-ipc-smoke',
        'name': 'Worker IPC Smoke',
        'startDeviceNumber': 1,
        'endDeviceNumber': 2,
        'clientIdPrefix': 'smoke-',
        'usernamePrefix': 'smoke-',
        'passwordPrefix': 'smoke-',
        'format': 'tb-ts',
        'totalKeyCount': 1,
        'changeRatio': 1.0,
        'changeIntervalSeconds': 1,
        'fullIntervalSeconds': 0,
        'customKeys': <Map<String, dynamic>>[],
      },
    ],
    'subscriptions': <Map<String, dynamic>>[],
  };
}
