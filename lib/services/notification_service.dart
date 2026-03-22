import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

/// Top-level callback for handling notification taps when app is killed.
/// Must be a top-level function (not a method) for background isolates.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  debugPrint('📱 Background notification tapped: ${response.payload}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionsGranted = false;

  /// Initialize the notification service. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Initialize timezone database FIRST
    tzdata.initializeTimeZones();
    
    // 2. Set local timezone using IANA name
    _setLocalTimezone();

    // 3. Platform-specific initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 4. Initialize plugin with BOTH foreground and background callbacks
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    // 5. Request all necessary permissions
    _permissionsGranted = await _requestPermissions();

    _initialized = true;
    debugPrint('✅ NotificationService initialized (permissions=$_permissionsGranted)');
  }

  /// Set the local timezone — handles the IST abbreviation issue
  void _setLocalTimezone() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      String ianaName;

      // Map by UTC offset → IANA name
      final offsetMinutes = offset.inMinutes;
      switch (offsetMinutes) {
        case 330:
          ianaName = 'Asia/Kolkata'; // IST (India)
          break;
        case 0:
          ianaName = 'UTC';
          break;
        case -300:
          ianaName = 'America/New_York'; // EST
          break;
        case -360:
          ianaName = 'America/Chicago'; // CST
          break;
        case -420:
          ianaName = 'America/Denver'; // MST
          break;
        case -480:
          ianaName = 'America/Los_Angeles'; // PST
          break;
        case 60:
          ianaName = 'Europe/London'; // BST
          break;
        case 120:
          ianaName = 'Europe/Berlin'; // CEST
          break;
        case 540:
          ianaName = 'Asia/Tokyo'; // JST
          break;
        default:
          // Try system name, fallback to Asia/Kolkata
          try {
            final sysName = DateTime.now().timeZoneName;
            tz.getLocation(sysName); // test if it works
            ianaName = sysName;
          } catch (_) {
            ianaName = 'Asia/Kolkata';
          }
      }

      tz.setLocalLocation(tz.getLocation(ianaName));
      debugPrint('✅ Timezone: $ianaName (offset=${offset.inMinutes}min)');
    } catch (e) {
      // Last resort — use Asia/Kolkata
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
        debugPrint('⚠️ Timezone fallback to Asia/Kolkata');
      } catch (_) {
        debugPrint('❌ Timezone setup completely failed');
      }
    }
  }

  /// Request all necessary permissions. Returns true if notifications allowed.
  Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) return true;

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return false;

    // Request notification permission (Android 13+)
    final notifGranted =
        await androidPlugin.requestNotificationsPermission() ?? false;
    debugPrint('📱 Notification permission: $notifGranted');

    // Request exact alarm permission (Android 12+)
    final alarmGranted =
        await androidPlugin.requestExactAlarmsPermission() ?? false;
    debugPrint('⏰ Exact alarm permission: $alarmGranted');

    if (!notifGranted) {
      debugPrint('❌ Notification permission DENIED — notifications will not work');
    }

    return notifGranted;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 Notification tapped: ${response.payload}');
  }

  /// Schedule a notification at an exact time.
  /// Works in foreground, background, and when app is killed.
  Future<bool> scheduleTaskReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Ensure initialized
    if (!_initialized) await initialize();

    // Skip if in the past
    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) {
      debugPrint('⚠️ Skip (past): $title @ $scheduledDate');
      return false;
    }

    // Build TZDateTime
    final scheduledTZ = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      scheduledDate.hour,
      scheduledDate.minute,
    );

    // Re-verify it's in the future after TZ conversion
    final nowTZ = tz.TZDateTime.now(tz.local);
    if (!scheduledTZ.isAfter(nowTZ)) {
      debugPrint('⚠️ Skip (TZ past): $title @ $scheduledTZ (now=$nowTZ)');
      return false;
    }

    final deltaMinutes = scheduledTZ.difference(nowTZ).inMinutes;
    debugPrint('📅 Scheduling: "$title" in $deltaMinutes min ($scheduledTZ)');

    // Notification details — HIGH importance, default sound for reliability
    const androidDetails = AndroidNotificationDetails(
      'hledger_task_reminders',
      'Task Reminders',
      channelDescription: 'Reminders for your tasks and deadlines',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      enableLights: true,
      // Show on lock screen
      visibility: NotificationVisibility.public,
      // Keep notification until dismissed
      ongoing: false,
      // Category for alarms
      category: AndroidNotificationCategory.alarm,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      // Use alarmClock mode — most reliable, shows alarm icon in status bar
      // This uses AlarmManager.setAlarmClock() under the hood which is
      // resistant to Doze mode and OEM battery optimizations
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTZ,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: 'task_$id',
      );

      // Verify scheduling
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      final verified = pending.any((p) => p.id == id);
      debugPrint('✅ Scheduled: "$title" (id=$id, verified=$verified, '
          'pending=${pending.length} total)');
      
      return verified;
    } catch (e) {
      debugPrint('❌ Schedule failed: $e');
      
      // Fallback: try with inexact mode (less reliable but might work)
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledTZ,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'task_$id',
        );
        debugPrint('⚠️ Scheduled with inexact fallback');
        return true;
      } catch (e2) {
        debugPrint('❌ Inexact fallback also failed: $e2');
        // Show immediate notification to warn user
        await showImmediateNotification(
          id: id + 100000,
          title: '⚠️ Reminder could not be set',
          body: 'Please check app permissions for: $title',
        );
        return false;
      }
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    debugPrint('🗑️ Cancelled notification: $id');
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    debugPrint('🗑️ Cancelled all notifications');
  }

  /// Show a notification immediately (for testing or fallback)
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'hledger_task_reminders',
      'Task Reminders',
      channelDescription: 'Reminders for your tasks and deadlines',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(id, title, body, details);
    debugPrint('✅ Immediate notification: "$title"');
  }

  /// Get all pending (scheduled) notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  /// Debug helper: log all pending notifications
  Future<void> debugLogPending() async {
    final pending = await getPendingNotifications();
    debugPrint('📋 Pending notifications (${pending.length}):');
    for (final p in pending) {
      debugPrint('   #${p.id}: ${p.title} — ${p.body}');
    }
  }
}