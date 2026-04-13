import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/utils/notification_service.dart';

class MorningPromptSettings {
  const MorningPromptSettings({
    required this.enabled,
    required this.time,
  });

  final bool enabled;
  final TimeOfDay time;

  MorningPromptSettings copyWith({
    bool? enabled,
    TimeOfDay? time,
  }) {
    return MorningPromptSettings(
      enabled: enabled ?? this.enabled,
      time: time ?? this.time,
    );
  }
}

final morningPromptProvider =
    StateNotifierProvider<MorningPromptController, MorningPromptSettings>(
  (ref) => MorningPromptController(NotificationService()),
);

class MorningPromptController extends StateNotifier<MorningPromptSettings> {
  MorningPromptController(this._notifications)
      : super(const MorningPromptSettings(
          enabled: false,
          time: TimeOfDay(hour: 8, minute: 0),
        ));

  final NotificationService _notifications;

  Future<void> setEnabled(bool value, {required int taskCount}) async {
    if (!value) {
      await _notifications.cancelDailyMorningPrompt();
      state = state.copyWith(enabled: false);
      return;
    }

    await _notifications.scheduleDailyMorningPrompt(
      hour: state.time.hour,
      minute: state.time.minute,
      taskCount: taskCount,
    );
    state = state.copyWith(enabled: true);
  }

  Future<void> setTime(TimeOfDay time, {required int taskCount}) async {
    state = state.copyWith(time: time);

    if (!state.enabled) return;

    await _notifications.scheduleDailyMorningPrompt(
      hour: time.hour,
      minute: time.minute,
      taskCount: taskCount,
    );
  }
}
