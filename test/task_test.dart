import 'package:flutter_test/flutter_test.dart';
import 'package:hledger/models/task.dart';

Task _task({String id = 'abc123', bool reminder = true, DateTime? at}) => Task(
      id: id,
      userId: 'u1',
      title: 'Pay rent',
      reminder: reminder,
      reminderTime: at,
      createdAt: DateTime(2026, 8, 20, 10),
    );

void main() {
  group('notificationId', () {
    test('is stable for the same document id', () {
      expect(_task().notificationId, _task().notificationId);
    });

    test('differs between documents', () {
      expect(_task(id: 'abc123').notificationId,
          isNot(_task(id: 'abc124').notificationId));
    });

    test('fits in a Java int, which is what AlarmManager receives', () {
      for (final id in ['', 'a', 'mQYJZitph5yRpB1zT1pZ', 'x' * 64]) {
        final value = _task(id: id).notificationId;
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });

    test('survives a Firestore round trip', () {
      final original = _task(at: DateTime(2026, 8, 21, 16, 48));
      final restored = Task.fromJson({
        ...original.toFirestore(),
        'id': original.id,
        'created_at': original.createdAt.toIso8601String(),
        'reminder_time': original.reminderTime!.toIso8601String(),
      });

      expect(restored.notificationId, original.notificationId);
      expect(restored.reminderTime, original.reminderTime);
      expect(restored.reminder, isTrue);
    });
  });

  group('reminder persistence', () {
    test('a reminder time is written to Firestore', () {
      final map = _task(at: DateTime(2026, 8, 21, 16, 48)).toFirestore();
      expect(map['reminder'], isTrue);
      expect(map['reminder_time'], DateTime(2026, 8, 21, 16, 48));
    });

    test('no reminder time means no field', () {
      final map = _task(reminder: false).toFirestore();
      expect(map['reminder'], isFalse);
      expect(map.containsKey('reminder_time'), isFalse);
    });
  });
}
