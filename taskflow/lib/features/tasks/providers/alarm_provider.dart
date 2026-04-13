import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../services/alarm_restoration_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final alarmRestorationServiceProvider =
    Provider<AlarmRestorationService>((ref) {
  final database = ref.watch(databaseProvider);
  return AlarmRestorationService(database);
});

/// Restore alarms on app startup
final restoreAlarmsProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(alarmRestorationServiceProvider);
  await service.restoreAlarms();
});
