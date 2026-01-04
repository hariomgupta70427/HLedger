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
      await androidPlugin.requestNotificationsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('📱 Notification tapped: ${response.payload}');
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
      print('⚠️ Scheduled date is in the past, skipping notification');
      return;
    }

    final tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      channelDescription: 'Notifications for task reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
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

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTZDate,
        notificationDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

      print('✅ Notification scheduled: "$title" for $scheduledDate');
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
}