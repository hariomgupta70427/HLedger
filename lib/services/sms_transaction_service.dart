import 'dart:async';
import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'upi_parser.dart';

/// Callback type for when a UPI transaction is detected from a notification.
typedef OnTransactionDetected = void Function(UpiParseResult result);

/// Notification-based monitoring service for auto-detecting UPI transactions.
///
/// Uses [NotificationListenerService] to listen for incoming bank/UPI
/// notifications in real-time. Only fires [onTransactionDetected] for
/// notification content that [UpiParser] can successfully parse.
///
/// This avoids the restricted READ_SMS permission on Android 13+.
class SmsTransactionService {
  SmsTransactionService._();

  static final SmsTransactionService _instance = SmsTransactionService._();
  static SmsTransactionService get instance => _instance;

  bool _initialized = false;
  bool _hasPermission = false;
  StreamSubscription<ServiceNotificationEvent>? _subscription;

  /// Detected UPI results from notification monitoring.
  final List<UpiParseResult> _detectedTransactions = [];
  List<UpiParseResult> get detectedTransactions =>
      List.unmodifiable(_detectedTransactions);

  /// Stream controller for real-time incoming notification detections.
  final _controller = StreamController<UpiParseResult>.broadcast();
  Stream<UpiParseResult> get onTransactionDetected => _controller.stream;

  /// Whether notification listener permission has been granted.
  bool get hasPermission => _hasPermission;

  /// Whether the service has been initialized.
  bool get isInitialized => _initialized;

  /// Check and request notification listener permission, then start listening.
  Future<bool> initialize() async {
    if (_initialized) return _hasPermission;

    try {
      _hasPermission =
          await NotificationListenerService.isPermissionGranted();

      if (_hasPermission) {
        _startListening();
      }

      _initialized = true;
      debugPrint(
          '📱 Notification Listener initialized. Permission: $_hasPermission');
    } catch (e) {
      debugPrint('❌ Notification Listener init failed: $e');
      _initialized = true;
      _hasPermission = false;
    }

    return _hasPermission;
  }

  /// Request notification listener permission (opens Android Settings).
  /// Returns true once granted.
  Future<bool> requestPermission() async {
    try {
      _hasPermission =
          await NotificationListenerService.requestPermission();

      if (_hasPermission && _subscription == null) {
        _startListening();
      }

      debugPrint('📱 Notification permission result: $_hasPermission');
      return _hasPermission;
    } catch (e) {
      debugPrint('❌ Permission request failed: $e');
      return false;
    }
  }

  /// Start listening to the notification stream.
  void _startListening() {
    _subscription?.cancel();
    _subscription =
        NotificationListenerService.notificationsStream.listen(
      _onNotification,
      onError: (e) {
        debugPrint('❌ Notification stream error: $e');
      },
    );
    debugPrint('🔔 Notification listener started');
  }

  /// Called when any notification arrives.
  void _onNotification(ServiceNotificationEvent event) {
    // Skip removed notifications
    if (event.hasRemoved == true) return;

    // Build text from notification title + content
    final title = event.title ?? '';
    final content = event.content ?? '';

    // Skip empty notifications
    if (title.isEmpty && content.isEmpty) return;

    // Combine title and content for parsing
    final fullText = '$title $content'.trim();

    // Try to parse as UPI transaction
    final result = UpiParser.parse(fullText);
    if (result != null) {
      _detectedTransactions.insert(0, result);
      _controller.add(result);
      debugPrint(
          '🔔 UPI notification detected from ${event.packageName}: $result');
    }
  }

  /// Remove a detected transaction after the user imports or dismisses it.
  void removeDetected(int index) {
    if (index >= 0 && index < _detectedTransactions.length) {
      _detectedTransactions.removeAt(index);
    }
  }

  /// Clear all detected transactions.
  void clearAll() {
    _detectedTransactions.clear();
  }

  /// Dispose resources.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller.close();
  }
}
