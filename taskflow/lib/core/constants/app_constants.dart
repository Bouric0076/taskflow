class AppConstants {
  // App
  static const appName = 'TaskFlow';
  static const appVersion = '1.0.0';

  // DB
  static const dbName = 'taskflow.db';
  static const dbVersion = 2;

  // Notification channels
  static const notifChannelId = 'taskflow_reminders';
  static const notifChannelName = 'Task Reminders';
  static const notifChannelDesc =
      'Notifications for task deadlines and reminders';
  static const alarmChannelId = 'taskflow_alarms';
  static const alarmChannelName = 'Task Alarms';
  static const alarmChannelDesc = 'Alarm sounds when task time is reached';

  // Reminder offsets (minutes)
  static const reminderOffsets = [5, 15, 30, 60, 120, 1440];
  static const defaultReminderMinutes = 15;

  // Snooze options (minutes)
  static const snoozeOptions = [5, 15, 30];

  // Priorities
  static const priorityNormal = 0;
  static const priorityImportant = 1;
  static const priorityCritical = 2;

  // Nav indices
  static const navToday = 0;
  static const navUpcoming = 1;
  static const navAll = 2;
  static const navSettings = 3;
}
