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

    // Initialize timezone
    tzdata.initializeTimeZones();
    
    // Set local timezone
    final String timeZoneName = DateTime.now().timeZoneName;
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // Fallback to UTC offset calculation
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      // Try to find a timezone with this offset
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); // Default for IST
      } catch (_) {
        print('⚠️ Could not set timezone, using UTC');
      }
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

    print('📅 Scheduling notification for: $scheduledTZDate (original: $scheduledDate)');

    // Android notification details with custom sound
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      channelDescription: 'Notifications for task due date reminders',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'), // Uses res/raw/notification.mp3
      enableLights: true,
      fullScreenIntent: true, // Wake up device for important notifications
    );

    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification.mp3', // For iOS
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // EXACT timing!
        payload: 'task_$id',
      );

      print('✅ Notification scheduled: "$title" for $scheduledTZDate');
    } catch (e) {
      print('❌ Error scheduling notification: $e');
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
      sound: RawResourceAndroidNotificationSound('notification'),
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