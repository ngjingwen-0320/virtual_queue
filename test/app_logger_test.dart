
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'package:virtual_queue/services/app_logger.dart';

void main() {

  // TEST 1: Application and security event logging
  test('Records application and security events', () async {
    final events = <LogRecord>[];

    Logger.root.level = Level.ALL;

    final subscription =
    Logger.root.onRecord.listen(events.add);

    AppLogger.info(
      'QueueService',
      'Queue cancellation completed',
    );

    AppLogger.warning(
      'InputValidation',
      'Invalid reservation input',
    );

    AppLogger.securityEvent(
      'Unauthorised operation attempted',
    );

    expect(events.length, 3);
    expect(events[0].level, Level.INFO);
    expect(events[1].level, Level.WARNING);
    expect(events[2].loggerName, 'Security');

    for (final record in events) {
      print(
        '[${record.time.toIso8601String()}] '
            '[${record.level.name}] '
            '[${record.loggerName}] '
            '${record.message}',
      );
    }

    await subscription.cancel();
  });


  // TEST 2: Severe application error logging
  test('Records severe application errors', () async {
    final events = <LogRecord>[];

    Logger.root.level = Level.ALL;

    final subscription =
    Logger.root.onRecord.listen(events.add);

    AppLogger.error(
      'QueueService',
      'Queue cancellation failed',
    );

    expect(events.length, 1);
    expect(events[0].level, Level.SEVERE);
    expect(events[0].loggerName, 'QueueService');
    expect(
      events[0].message,
      'Queue cancellation failed',
    );

    for (final record in events) {
      print(
        '[${record.time.toIso8601String()}] '
            '[${record.level.name}] '
            '[${record.loggerName}] '
            '${record.message}',
      );
    }

    await subscription.cancel();
  });


  // TEST 3: Multiple security event logging
  test('Records multiple security events correctly', () async {
    final events = <LogRecord>[];

    Logger.root.level = Level.ALL;

    final subscription =
    Logger.root.onRecord.listen(events.add);

    AppLogger.securityEvent(
      'Invalid reservation input detected',
    );

    AppLogger.securityEvent(
      'Login authentication failed',
    );

    AppLogger.securityEvent(
      'Unauthorised operation attempted',
    );

    expect(events.length, 3);

    for (final record in events) {
      expect(record.loggerName, 'Security');
      expect(record.level, Level.WARNING);
    }

    expect(
      events.map((record) => record.message).toList(),
      [
        'Invalid reservation input detected',
        'Login authentication failed',
        'Unauthorised operation attempted',
      ],
    );

    for (final record in events) {
      print(
        '[${record.time.toIso8601String()}] '
            '[${record.level.name}] '
            '[${record.loggerName}] '
            '${record.message}',
      );
    }

    await subscription.cancel();
  });


  test('Filters log records based on severity level', () async {
    final events = <LogRecord>[];

    // Save the original level.
    final originalLevel = Logger.root.level;

    // Only allow WARNING and SEVERE.
    Logger.root.level = Level.WARNING;

    final subscription =
    Logger.root.onRecord.listen(events.add);

    try {
      AppLogger.info(
        'QueueService',
        'Queue joined successfully',
      );

      AppLogger.warning(
        'InputValidation',
        'Invalid reservation input',
      );

      AppLogger.error(
        'QueueService',
        'Queue cancellation failed',
      );

      // INFO should be ignored.
      expect(events.length, 2);

      // WARNING and SEVERE should be recorded.
      expect(events[0].level, Level.WARNING);
      expect(events[1].level, Level.SEVERE);

      // Display the accepted records.
      for (final record in events) {
        print(
          '[${record.level.name}] '
              '[${record.loggerName}] '
              '${record.message}',
        );
      }
    } finally {
      await subscription.cancel();

      // Restore the previous configuration.
      Logger.root.level = originalLevel;
    }
  });

  test('Records ticket events during debug mode', () async {
    final events = <LogRecord>[];

    Logger.root.level = Level.ALL;

    final subscription =
    Logger.root.onRecord.listen(events.add);

    try {
      AppLogger.ticketEvent(
        '🎬 Initializing Cancellation Batch',
        'TEST-TICKET-001',
      );

      if (kDebugMode) {
        expect(events.length, 1);
        expect(events[0].level, Level.INFO);
        expect(events[0].loggerName, 'QueueService');

        expect(
          events[0].message,
          '🎬 Initializing Cancellation Batch | '
              'Ticket ID: TEST-TICKET-001',
        );

        for (final record in events) {
          print(
            '[${record.level.name}] '
                '[${record.loggerName}] '
                '${record.message}',
          );
        }
      } else {
        expect(events, isEmpty);
      }
    } finally {
      await subscription.cancel();
    }
  });

  // TEST 4: Logging configuration
  // Run this last to avoid affecting earlier tests.
  test('Initializes logging configuration correctly', () {
    AppLogger.initialize();

    if (kDebugMode) {
      expect(Logger.root.level, Level.ALL);
    } else {
      expect(Logger.root.level, Level.OFF);
    }

    print('Logging configuration initialized successfully');
    print('Debug mode: $kDebugMode');
    print('Root logging level: ${Logger.root.level.name}');
  });
}