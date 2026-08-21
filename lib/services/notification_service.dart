import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'upi_parser.dart';

/// Payload marking a "transaction detected" alert, so a tap can be routed to
/// the review inbox rather than silently doing nothing.
const String kTransactionDetectedPayload = 'txn_detected';

/// How precisely a reminder could actually be scheduled.
///
/// Exact alarms are special access the user can refuse, and this app is not
/// entitled to the automatic grant — Play reserves that for alarm-clock and
/// calendar apps. So "scheduled" is not a yes/no: it can land on the minute, or
/// inside a window, and the user is entitled to know which.
enum ReminderPrecision {
  /// Fires on the minute.
  exact,

  /// Fires inside a system-chosen window, typically minutes late in Doze.
  approximate,

  /// Not scheduled at all.
  failed,
}

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

  static const String _reminderChannelId = 'hledger_task_reminders';
  static const String _detectionChannelId = 'hledger_txn_detected';

  static final StreamController<String> _taps =
      StreamController<String>.broadcast();

  /// Payloads of notifications the user tapped while the app was running.
  static Stream<String> get taps => _taps.stream;

  static String? _launchPayload;

  /// The payload of the notification that started the app, once.
  ///
  /// A cold-start tap happens before anything can be listening, so it cannot
  /// arrive on [taps] — the first caller reads it here instead, and it is
  /// cleared so a later rebuild does not navigate a second time.
  static String? takeLaunchPayload() {
    final payload = _launchPayload;
    _launchPayload = null;
    return payload;
  }

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

    // 6. Declare the channels up front. They used to be created lazily by the
    // first notification that displayed, so until one fired the user could not
    // find or configure them in system settings — and a silenced channel was
    // indistinguishable from a reminder that was never scheduled.
    await _createChannels();

    // 7. Capture a tap that launched the app from cold, before any listener
    // could exist.
    try {
      final launch =
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _launchPayload = launch?.notificationResponse?.payload;
      }
    } catch (e) {
      debugPrint('⚠️ Launch details unavailable: $e');
    }

    _initialized = true;
    debugPrint('✅ NotificationService initialized (permissions=$_permissionsGranted)');
  }

  Future<void> _createChannels() async {
    if (!Platform.isAndroid) return;
    final android = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    try {
      await android.createNotificationChannel(const AndroidNotificationChannel(
        _reminderChannelId,
        'Task Reminders',
        description: 'Reminders for your tasks and deadlines',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));
      await android.createNotificationChannel(const AndroidNotificationChannel(
        _detectionChannelId,
        'Transaction Alerts',
        description: 'Alerts when a new bank/UPI transaction is detected',
        importance: Importance.high,
        playSound: true,
      ));
    } catch (e) {
      debugPrint('⚠️ Channel setup failed: $e');
    }
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

    // Exact-alarm access is NOT requested here. It is special access the user
    // grants on a settings screen, and asking for it at startup — before any
    // reminder exists — is an ambush with no context. It is offered at the point
    // a reminder is actually set, and only when it turns out to be needed.

    if (!notifGranted) {
      debugPrint('❌ Notification permission DENIED — notifications will not work');
    }

    return notifGranted;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 Notification tapped: ${response.payload}');
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty && !_taps.isClosed) {
      _taps.add(payload);
    }
  }

  /// Whether the system will currently let this app set an alarm to the minute.
  ///
  /// Special access the user can withhold. Without the automatic grant — which
  /// Play reserves for alarm-clock and calendar apps — this can be false at any
  /// time, so it is checked per schedule rather than assumed once.
  Future<bool> canScheduleExactReminders() async {
    if (!Platform.isAndroid) return true;
    final android = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    try {
      return await android.canScheduleExactNotifications() ?? false;
    } catch (e) {
      debugPrint('⚠️ Exact-alarm capability check failed: $e');
      return false;
    }
  }

  /// Sends the user to the system screen where exact alarms can be allowed.
  Future<void> requestExactReminders() async {
    final android = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('⚠️ Exact-alarm request failed: $e');
    }
  }

  /// Schedule a task reminder, as precisely as the system currently allows.
  ///
  /// Returns how it actually landed. Exact scheduling needs special access this
  /// app is not automatically entitled to, so a reminder may legitimately be
  /// approximate — and the caller has to be able to say so rather than claim a
  /// precision it did not get.
  Future<ReminderPrecision> scheduleTaskReminder({
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
      return ReminderPrecision.failed;
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
      return ReminderPrecision.failed;
    }

    final deltaMinutes = scheduledTZ.difference(nowTZ).inMinutes;
    debugPrint('📅 Scheduling: "$title" in $deltaMinutes min ($scheduledTZ)');

    // Notification details — HIGH importance, default sound for reliability
    const androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
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
      ongoing: false,
      // A reminder, not an alarm clock. `alarm` here would claim a category the
      // app is not entitled to present as, alongside the alarm-clock status icon.
      category: AndroidNotificationCategory.reminder,
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

    // Ask before attempting, rather than scheduling and catching a
    // SecurityException: the answer decides what we can promise the user.
    final exactAllowed = await canScheduleExactReminders();

    if (exactAllowed) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledTZ,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          // setExactAndAllowWhileIdle: exact and Doze-resistant, without
          // presenting as a user-set alarm clock.
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'task_$id',
        );

        if (await _isPending(id)) {
          debugPrint('✅ Scheduled exactly: "$title" (id=$id)');
          return ReminderPrecision.exact;
        }
      } catch (e) {
        debugPrint('⚠️ Exact schedule failed, falling back: $e');
      }
    } else {
      debugPrint('ℹ️ Exact alarms not permitted — scheduling approximately');
    }

    // Inexact still fires, just inside a window rather than to the minute.
    // Better than no reminder, and the caller tells the user it is approximate.
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
      if (await _isPending(id)) {
        debugPrint('✅ Scheduled approximately: "$title" (id=$id)');
        return ReminderPrecision.approximate;
      }
      debugPrint('❌ Schedule reported success but nothing is pending');
      return ReminderPrecision.failed;
    } catch (e) {
      debugPrint('❌ Inexact schedule also failed: $e');
      return ReminderPrecision.failed;
    }
  }

  /// Whether the plugin has [id] on its schedule.
  ///
  /// This reads the plugin's own store, not AlarmManager, so it proves the
  /// request was accepted and recorded — not that Android will definitely fire.
  Future<bool> _isPending(int id) async {
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      return pending.any((p) => p.id == id);
    } catch (e) {
      debugPrint('⚠️ Could not read pending notifications: $e');
      return false;
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
      _reminderChannelId,
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

  /// Show an immediate "transaction detected" notification for an auto-detected
  /// UPI/bank SMS. Safe to call from a background isolate — it self-initializes.
  ///
  /// Uses a dedicated channel so users can silence transaction alerts separately
  /// from task reminders.
  Future<void> showTransactionDetected(UpiParseResult parsed) async {
    if (!_initialized) await initialize();

    final isExpense = parsed.transactionType == 'expense';
    final amount = parsed.amount == parsed.amount.roundToDouble()
        ? parsed.amount.toStringAsFixed(0)
        : parsed.amount.toStringAsFixed(2);
    final who = parsed.displayLabel;
    final title = isExpense
        ? '₹$amount paid'
        : '₹$amount received';
    final body = '$who • Tap to review and add to your Khaata';

    const androidDetails = AndroidNotificationDetails(
      _detectionChannelId,
      'Transaction Alerts',
      channelDescription: 'Alerts when a new bank/UPI transaction is detected',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      autoCancel: true,
      visibility: NotificationVisibility.private,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Unique-ish id per detection so alerts stack rather than overwrite.
    final id = 200000 + (DateTime.now().millisecondsSinceEpoch % 100000);
    await _notificationsPlugin.show(id, title, body, details,
        payload: kTransactionDetectedPayload);
    debugPrint('✅ Transaction alert shown: "$title"');
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