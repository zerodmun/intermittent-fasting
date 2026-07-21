import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

void main() {
  tz.initializeTimeZones();
  final offset = DateTime.now().timeZoneOffset;
  final hours = offset.inHours;
  final sign = hours >= 0 ? '-' : '+';
  final absHours = hours.abs();
  final gmtName = 'Etc/GMT$sign$absHours';
  
  final loc = tz.getLocation(gmtName);
  tz.setLocalLocation(loc);
  
  print('DateTime.now(): ${DateTime.now()}');
  print('tz.TZDateTime.now(tz.local): ${tz.TZDateTime.now(tz.local)}');
}
