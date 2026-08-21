import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One alert captured by the native listener, as the posting app worded it.
class CapturedAlert {
  const CapturedAlert({
    required this.key,
    required this.packageName,
    required this.postedAt,
    required this.title,
    required this.body,
  });

  /// Android's own stable identity for the notification.
  final String key;
  final String packageName;
  final DateTime postedAt;
  final String title;
  final String body;

  /// Title and body together, which is how a bank alert reads.
  String get text => '$title $body'.trim();

  static CapturedAlert? fromMap(Map<Object?, Object?> map) {
    final key = map['key'] as String?;
    if (key == null || key.isEmpty) return null;
    final posted = map['postedAt'] as int? ?? 0;
    return CapturedAlert(
      key: key,
      packageName: map['package'] as String? ?? '',
      postedAt: posted > 0
          ? DateTime.fromMillisecondsSinceEpoch(posted)
          : DateTime.now(),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
    );
  }
}

/// Dart's view of the native notification-capture layer.
///
/// The heavy lifting is in Kotlin on purpose: Android keeps the listener service
/// bound long after the Flutter engine is gone, so a capture path that lives in
/// Dart misses every alert that arrives while the app is closed. Here we only
/// read the queue the service has already written, and confirm what we stored.
class NotificationCapture {
  NotificationCapture._();

  static const MethodChannel _method =
      MethodChannel('hledger/notification_capture');
  static const EventChannel _events =
      EventChannel('hledger/notification_capture/events');

  /// Fires when the native queue grows. Carries no payload — the queue is the
  /// record, so there is exactly one way to read a capture.
  static Stream<void> get onCaptured =>
      _events.receiveBroadcastStream().map((_) {});

  static Future<bool> isPermissionGranted() async {
    try {
      return await _method.invokeMethod<bool>('isPermissionGranted') ?? false;
    } on PlatformException catch (e) {
      debugPrint('❌ Notification access check failed: $e');
      return false;
    } on MissingPluginException {
      // Non-Android platform, or an engine without the bridge attached.
      return false;
    }
  }

  static Future<void> openPermissionSettings() async {
    try {
      await _method.invokeMethod<void>('openPermissionSettings');
    } on PlatformException catch (e) {
      debugPrint('❌ Could not open notification settings: $e');
    } on MissingPluginException {
      debugPrint('❌ Capture bridge unavailable');
    }
  }

  /// Everything queued. Does not remove — call [acknowledge] once stored.
  static Future<List<CapturedAlert>> drain() async {
    try {
      final raw = await _method.invokeListMethod<Object?>('drain');
      if (raw == null) return const <CapturedAlert>[];
      return raw
          .whereType<Map<Object?, Object?>>()
          .map(CapturedAlert.fromMap)
          .whereType<CapturedAlert>()
          .toList();
    } on PlatformException catch (e) {
      debugPrint('❌ Capture drain failed: $e');
      return const <CapturedAlert>[];
    } on MissingPluginException {
      return const <CapturedAlert>[];
    }
  }

  /// Drops exactly the captures we have stored, leaving the rest for next time.
  static Future<void> acknowledge(List<String> keys) async {
    if (keys.isEmpty) return;
    try {
      await _method.invokeMethod<void>('acknowledge', {'keys': keys});
    } on PlatformException catch (e) {
      debugPrint('❌ Capture acknowledge failed: $e');
    } on MissingPluginException {
      // Nothing to acknowledge to.
    }
  }

  /// Sources the native layer passed over, and why — so an app that posts
  /// perfectly good alerts but is not allowlisted can be found instead of
  /// silently ignored forever.
  static Future<Map<String, String>> skippedSources() async {
    try {
      final raw = await _method.invokeMapMethod<String, String>('skippedSources');
      return raw ?? const <String, String>{};
    } on PlatformException catch (e) {
      debugPrint('❌ Skipped-source read failed: $e');
      return const <String, String>{};
    } on MissingPluginException {
      return const <String, String>{};
    }
  }
}
