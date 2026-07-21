import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

void main() {
  tz.initializeTimeZones();
  
  final offset = DateTime.now().timeZoneOffset;
  final offsetMs = offset.inMilliseconds;
  
  print('Target offset: $offsetMs ms');
  
  // Let's find any location in the database where the current offset is equal to offsetMs
  final now = DateTime.now().millisecondsSinceEpoch;
  String? matchedLocation;
  
  for (final entry in tz.timeZoneDatabase.locations.entries) {
    final loc = entry.value;
    final timeZone = loc.timeZone(now);
    if (timeZone.offset == offsetMs) {
      matchedLocation = entry.key;
      break;
    }
  }
  
  print('Matched Location: $matchedLocation');
  if (matchedLocation != null) {
    final loc = tz.getLocation(matchedLocation);
    tz.setLocalLocation(loc);
    print('tz.TZDateTime.now(tz.local): ${tz.TZDateTime.now(tz.local)}');
  }
}
