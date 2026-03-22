import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone database
    tzdata.initializeTimeZones();
    
    // Set local timezone — use IANA name directly.
    // DateTime.now().timeZoneName returns abbreviations like 'IST' which
    // tz.getLocation() doesn't understand. Use the IANA name instead.
    try {
      // Try to detect from UTC offset
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      String ianaName;
      
      // Map common Indian offset to IANA name
      if (offset.inHours == 5 && offset.inMinutes == 330) {
        ianaName = 'Asia/Kolkata';
      } else {
        // Fallback: try the timeZoneName first, then default
        try {
          tz.setLocalLocation(tz.getLocation(now.timeZoneName));
          ianaName = now.timeZoneName; // worked — it was already IANA
        } catch (_) {
          ianaName = 'Asia/Kolkata'; // hard fallback
        }
      }
      
      tz.setLocalLocation(tz.getLocation(ianaName));
      print('✅ Timezone set to: $ianaName');
    } catch (e) {
      print('⚠️ Timezone setup error: $e — using UTC');
    }

    // Android settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings  
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

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for Android 13+
    await _requestPermissions();

    _initialized = true;
    print('✅ NotificationService: Initialized successfully');
  }

  Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Request notification permission (Android 13+)
      final notificationGranted = await androidPlugin.requestNotificationsPermission();
      print('📱 Notification permission: $notificationGranted');
      
      // Request exact alarm permission (Android 12+)
      final exactAlarmGranted = await androidPlugin.requestExactAlarmsPermission();
      print('⏰ Exact alarm permission: $exactAlarmGranted');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('📱 Notification tapped: ${response.payload}');
    // Could navigate to task screen here if needed
  }

  Future<void> scheduleTaskReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Don't schedule if the date is in the past
    if (scheduledDate.isBefore(DateTime.now())) {
      print('⚠️ Scheduled date is in the past, skipping notification for: $title');
      return;
    }

    // Convert to TZDateTime
    final tz.TZDateTime scheduledTZDate = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      scheduledDate.hour,
      scheduledDate.minute,
      scheduledDate.second,
    );

    // Double-check: TZDateTime must be in the future
    final now = tz.TZDateTime.now(tz.local);
    if (scheduledTZDate.isBefore(now) || scheduledTZDate.isAtSameMomentAs(now)) {
      print('⚠️ TZDateTime $scheduledTZDate is not in the future (now=$now), skipping');
      return;
    }

    print('📅 Scheduling notification:');
    print('   Title: $title');
    print('   Original DateTime: $scheduledDate');
    print('   TZ DateTime: $scheduledTZDate');
    print('   Now: $now');
    print('   Delta: ${scheduledTZDate.difference(now).inMinutes} minutes from now');

    // Android notification details — use default sound for reliability
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      channelDescription: 'Notifications for task due date reminders',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      enableLights: true,
    );

    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTZDate,
        notificationDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'task_$id',
      );

      // Verify it's in pending list
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      final found = pending.any((p) => p.id == id);
      print('✅ Notification scheduled: "$title" for $scheduledTZDate (verified pending: $found)');
    } catch (e) {
      print('❌ Error scheduling notification: $e');
      // Try showing immediate notification as fallback so user knows something went wrong
      try {
        await showImmediateNotification(
          id: id,
          title: '⚠️ Reminder setup failed',
          body: 'Could not schedule: $title. Please try again.',
        );
      } catch (_) {}
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    print('🗑️ Notification cancelled: $id');
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    print('🗑️ All notifications cancelled');
  }

  // Show an immediate notification (for testing)
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      channelDescription: 'Notifications for task due date reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );

    print('✅ Immediate notification shown: "$title"');
  }

  // Get pending notifications for debugging
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }
}