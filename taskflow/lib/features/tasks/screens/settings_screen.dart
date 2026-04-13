import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/morning_prompt_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final morningPrompt = ref.watch(morningPromptProvider);
    final s = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // APPEARANCE
            _SettingSection(
              title: 'Appearance',
              children: [
                _SettingTile(
                  title: 'Dark Mode',
                  subtitle: s.isDarkMode ? 'Enabled' : 'Disabled',
                  leading: Icon(
                    s.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: Switch(
                    value: s.isDarkMode,
                    onChanged: (value) {
                      ref.read(appSettingsProvider.notifier).setDarkMode(value);
                    },
                  ),
                ),
              ],
            ),
            // NOTIFICATIONS
            _SettingSection(
              title: 'Notifications',
              children: [
                _SettingTile(
                  title: 'Enable Notifications',
                  subtitle: s.enableNotifications
                      ? 'You will receive task reminders'
                      : 'Notifications are off',
                  leading: Icon(
                    s.enableNotifications
                        ? Icons.notifications_active
                        : Icons.notifications_off_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: Switch(
                    value: s.enableNotifications,
                    onChanged: (value) {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setEnableNotifications(value);
                    },
                  ),
                ),
                if (s.enableNotifications)
                  _SettingTile(
                    title: 'Alarm Sounds',
                    subtitle: s.enableAlarmSounds ? 'Alarms will produce sound' : 'Silent mode',
                    leading: Icon(
                      s.enableAlarmSounds ? Icons.volume_up : Icons.volume_off,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    trailing: Switch(
                      value: s.enableAlarmSounds,
                      onChanged: (value) {
                        ref
                            .read(appSettingsProvider.notifier)
                            .setEnableAlarmSounds(value);
                      },
                    ),
                  ),
                _SettingTile(
                  title: 'Morning Prompt',
                  subtitle: morningPrompt.enabled
                      ? 'Daily reminder at ${morningPrompt.time.format(context)}'
                      : 'Disabled',
                  leading: Icon(
                    morningPrompt.enabled
                        ? Icons.coffee_outlined
                        : Icons.notifications_paused_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: Switch(
                    value: morningPrompt.enabled,
                    onChanged: (enabled) {
                      ref
                          .read(morningPromptProvider.notifier)
                          .setEnabled(enabled, taskCount: 0);
                    },
                  ),
                ),
                if (morningPrompt.enabled)
                  _SettingTile(
                    title: 'Notification Time',
                    subtitle: morningPrompt.time.format(context),
                    leading: const Icon(Icons.schedule),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: morningPrompt.time,
                      );
                      if (picked == null || !context.mounted) return;
                      await ref
                          .read(morningPromptProvider.notifier)
                          .setTime(picked, taskCount: 0);
                    },
                  ),
              ],
            ),
            // TASK DEFAULTS
            _SettingSection(
              title: 'Task Defaults',
              children: [
                _SettingTile(
                  title: 'Default Priority',
                  subtitle: s.defaultTaskPriority.toUpperCase(),
                  leading: const Icon(Icons.flag_outlined),
                  onTap: () => _showPriorityDialog(context, ref, s),
                ),
                _SettingTile(
                  title: 'Default Reminders',
                  subtitle: '${s.defaultReminders} minutes before',
                  leading: const Icon(Icons.alarm_on_outlined),
                  onTap: () => _showRemindersDialog(context, ref, s),
                ),
                _SettingTile(
                  title: 'Default Alarm Mode',
                  subtitle: s.defaultAlarmMode.replaceAll(RegExp(r'([A-Z])'), ' \$1').trim(),
                  leading: const Icon(Icons.schedule_outlined),
                  onTap: () => _showAlarmModeDialog(context, ref, s),
                ),
              ],
            ),
            // DISPLAY
            _SettingSection(
              title: 'Display',
              children: [
                _SettingTile(
                  title: 'Show Completed Tasks',
                  subtitle: s.showCompletedTasks
                      ? 'Completed tasks are visible'
                      : 'Completed tasks are hidden',
                  leading: const Icon(Icons.done_all_outlined),
                  trailing: Switch(
                    value: s.showCompletedTasks,
                    onChanged: (value) {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setShowCompletedTasks(value);
                    },
                  ),
                ),
              ],
            ),
            // DATA & PRIVACY
            _SettingSection(
              title: 'Data & Privacy',
              children: [
                _SettingTile(
                  title: 'Reset All Settings',
                  subtitle: 'Restore to default settings',
                  leading: const Icon(Icons.restore_outlined),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Reset Settings?'),
                        content: const Text('This will restore all settings to their defaults.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () {
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .resetToDefaults();
                              Navigator.pop(context);
                            },
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            // ABOUT
            _SettingSection(
              title: 'About',
              children: [
                _SettingTile(
                  title: 'TaskFlow',
                  subtitle: 'v1.0.0',
                  leading: const Icon(Icons.app_shortcut_outlined),
                ),
                _SettingTile(
                  title: 'Framework',
                  subtitle: 'Flutter + Riverpod + Drift',
                  leading: const Icon(Icons.build_outlined),
                ),
                _SettingTile(
                  title: 'Developed by',
                  subtitle: 'Sinaps Technology - Innovating for the future',
                  leading: const Icon(Icons.favorite_border_outlined),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showPriorityDialog(BuildContext context, WidgetRef ref, AppSettings settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Priority'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['normal', 'important', 'critical']
              .map((priority) => 
                  RadioListTile<String>(
                    title: Text(priority.toUpperCase()),
                    value: priority,
                    // ignore: deprecated_member_use
                    groupValue: settings.defaultTaskPriority,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(appSettingsProvider.notifier)
                            .setDefaultTaskPriority(value);
                        Navigator.pop(context);
                      }
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showRemindersDialog(BuildContext context, WidgetRef ref, AppSettings settings) {
    final controller = TextEditingController(text: settings.defaultReminders);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Reminders'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Minutes before task (comma-separated for multiple)'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g., 15,60,1440',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(appSettingsProvider.notifier)
                  .setDefaultReminders(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAlarmModeDialog(BuildContext context, WidgetRef ref, AppSettings settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Alarm Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['none', 'atStart', 'atDue', 'customTime']
              .map((mode) => 
                  RadioListTile<String>(
                    title: Text(mode.replaceAll(RegExp(r'([A-Z])'), ' \$1').trim()),
                    value: mode,
                    // ignore: deprecated_member_use
                    groupValue: settings.defaultAlarmMode,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(appSettingsProvider.notifier)
                            .setDefaultAlarmMode(value);
                        Navigator.pop(context);
                      }
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _SettingSection extends StatelessWidget {
  const _SettingSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: children.asMap().entries.map((entry) {
              final index = entry.key;
              final child = entry.value;
              final isLast = index == children.length - 1;
              return Column(
                children: [
                  child,
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 56,
                      endIndent: 16,
                      color: Theme.of(context).dividerColor,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (leading != null) ...[
                SizedBox(
                  width: 40,
                  child: Center(child: leading!),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
