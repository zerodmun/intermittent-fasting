import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

void main() {
  tz.initializeTimeZones();
  print('Number of locations: ${tz.timeZoneDatabase.locations.length}');
  final firstFew = tz.timeZoneDatabase.locations.keys.take(10).toList();
  print('First few locations: $firstFew');
}
