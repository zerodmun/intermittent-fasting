import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:fast_flow/core/services/notification_service.dart';

void main() {
  group('NotificationService Tests', () {
    setUpAll(() {
      tz.initializeTimeZones();
      // Set local location to Etc/GMT-7 (representing +07:00 timezone)
      tz.setLocalLocation(tz.getLocation('Etc/GMT-7'));
    });

    test('nextInstanceOfWeekday calculates target dates correctly', () {
      final now = tz.TZDateTime.now(tz.local);
      final service = NotificationService.instance;

      // 1. Test next Monday at 12:00
      final mondayTarget = service.nextInstanceOfWeekday(1, 12, 0);
      expect(mondayTarget.weekday, equals(1));
      expect(mondayTarget.hour, equals(12));
      expect(mondayTarget.minute, equals(0));
      expect(mondayTarget.isAfter(now), isTrue);

      // 2. Test next Sunday at 20:00
      final sundayTarget = service.nextInstanceOfWeekday(7, 20, 0);
      expect(sundayTarget.weekday, equals(7));
      expect(sundayTarget.hour, equals(20));
      expect(sundayTarget.minute, equals(0));
      expect(sundayTarget.isAfter(now), isTrue);

      // 3. Test next Thursday at 08:30
      final thursdayTarget = service.nextInstanceOfWeekday(4, 8, 30);
      expect(thursdayTarget.weekday, equals(4));
      expect(thursdayTarget.hour, equals(8));
      expect(thursdayTarget.minute, equals(30));
      expect(thursdayTarget.isAfter(now), isTrue);
    });
  });
}
