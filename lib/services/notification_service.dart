// Placeholder notification service - notifications disabled for compatibility
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    // Placeholder - notifications disabled
    print('NotificationService: Initialized (placeholder)');
  }

  Future<void> scheduleTaskReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Placeholder - notifications disabled
    print('NotificationService: Would schedule reminder - $title');
  }

  Future<void> cancelNotification(int id) async {
    // Placeholder - notifications disabled
    print('NotificationService: Would cancel notification - $id');
  }
}