import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// 🔐 Centralized application logging for security and debugging.
/// Provides consistent log levels and restricts sensitive ticket logging
/// to Debug mode.
class AppLogger {
  static bool _initialized = false;

  //Configure logging
  static void initialize() {
    if (_initialized == true) {
      return;
    }

    Logger.root.level =
        kDebugMode ? Level.ALL : Level.OFF;

    Logger.root.onRecord.listen((record) {
      if (!kDebugMode) return;

      debugPrint(
        '[${record.time.toIso8601String()}'
        '[${record.level.name}]'
        '[${record.loggerName}]'
        '${record.message}',
      );
    });
  }

  //record normal application events
  static void info(String source, String message) {
    Logger(source).info(message);
  }

  static void warning(String source, String message) {
    Logger(source).warning(message);
  }

  static void error(String source, String message) {
    Logger(source).severe(message);
  }

  //Record security-related events
  static void securityEvent(String message) {
    Logger('Security').warning(message);
  }

  /// 🎟️ Logs ticket-related events with their IDs only in Debug mode.
  /// Helps developers troubleshoot specific tickets without exposing
  /// identifiers through this method in production builds.
  static void ticketEvent(
      String message,
      String ticketId,
      ) {
    if (!kDebugMode) return;

    Logger('QueueService').info(
      '$message | Ticket ID: $ticketId',
    );
  }
}