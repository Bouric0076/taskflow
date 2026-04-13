import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.isDarkMode,
    required this.defaultReminders,
    required this.defaultTaskPriority,
    required this.enableNotifications,
    required this.enableAlarmSounds,
    required this.showCompletedTasks,
    required this.defaultAlarmMode,
  });

  final bool isDarkMode;
  final String defaultReminders; // comma-separated minutes
  final String defaultTaskPriority; // 'normal', 'important', 'critical'
  final bool enableNotifications;
  final bool enableAlarmSounds;
  final bool showCompletedTasks;
  final String defaultAlarmMode; // 'none', 'atStart', 'atDue', 'customTime'

  AppSettings copyWith({
    bool? isDarkMode,
    String? defaultReminders,
    String? defaultTaskPriority,
    bool? enableNotifications,
    bool? enableAlarmSounds,
    bool? showCompletedTasks,
    String? defaultAlarmMode,
  }) {
    return AppSettings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      defaultReminders: defaultReminders ?? this.defaultReminders,
      defaultTaskPriority: defaultTaskPriority ?? this.defaultTaskPriority,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableAlarmSounds: enableAlarmSounds ?? this.enableAlarmSounds,
      showCompletedTasks: showCompletedTasks ?? this.showCompletedTasks,
      defaultAlarmMode: defaultAlarmMode ?? this.defaultAlarmMode,
    );
  }
}

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController(this._prefs)
      : super(
          AppSettings(
            isDarkMode: _prefs.getBool('isDarkMode') ?? false,
            defaultReminders: _prefs.getString('defaultReminders') ?? '15,60,1440',
            defaultTaskPriority: _prefs.getString('defaultTaskPriority') ?? 'normal',
            enableNotifications: _prefs.getBool('enableNotifications') ?? true,
            enableAlarmSounds: _prefs.getBool('enableAlarmSounds') ?? true,
            showCompletedTasks: _prefs.getBool('showCompletedTasks') ?? true,
            defaultAlarmMode: _prefs.getString('defaultAlarmMode') ?? 'atDue',
          ),
        );

  final SharedPreferences _prefs;

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool('isDarkMode', value);
    state = state.copyWith(isDarkMode: value);
  }

  Future<void> setDefaultReminders(String value) async {
    await _prefs.setString('defaultReminders', value);
    state = state.copyWith(defaultReminders: value);
  }

  Future<void> setDefaultTaskPriority(String value) async {
    await _prefs.setString('defaultTaskPriority', value);
    state = state.copyWith(defaultTaskPriority: value);
  }

  Future<void> setEnableNotifications(bool value) async {
    await _prefs.setBool('enableNotifications', value);
    state = state.copyWith(enableNotifications: value);
  }

  Future<void> setEnableAlarmSounds(bool value) async {
    await _prefs.setBool('enableAlarmSounds', value);
    state = state.copyWith(enableAlarmSounds: value);
  }

  Future<void> setShowCompletedTasks(bool value) async {
    await _prefs.setBool('showCompletedTasks', value);
    state = state.copyWith(showCompletedTasks: value);
  }

  Future<void> setDefaultAlarmMode(String value) async {
    await _prefs.setString('defaultAlarmMode', value);
    state = state.copyWith(defaultAlarmMode: value);
  }

  Future<void> resetToDefaults() async {
    await _prefs.clear();
    state = const AppSettings(
      isDarkMode: false,
      defaultReminders: '15,60,1440',
      defaultTaskPriority: 'normal',
      enableNotifications: true,
      enableAlarmSounds: true,
      showCompletedTasks: true,
      defaultAlarmMode: 'atDue',
    );
  }
}

// Global instance - initialized in main()
late SharedPreferences _sharedPreferences;

void initializeSettings(SharedPreferences prefs) {
  _sharedPreferences = prefs;
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>((ref) {
  return AppSettingsController(_sharedPreferences);
});
