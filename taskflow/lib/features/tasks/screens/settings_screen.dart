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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        children: [
          _SettingsHeroCard(
            darkModeEnabled: s.isDarkMode,
            notificationsEnabled: s.enableNotifications,
            remindersLabel: s.defaultReminders,
          ),
          const SizedBox(height: 12),
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
            const SizedBox(height: 8),
            _DeveloperCard(
              appName: 'TaskFlow',
              version: 'v1.0.0',
              framework: 'Flutter + Riverpod + Drift',
              developer: 'Sinaps Technology',
              tagline: 'Innovating for the future',
            ),
        ],
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

class _SettingsHeroCard extends StatelessWidget {
  const _SettingsHeroCard({
    required this.darkModeEnabled,
    required this.notificationsEnabled,
    required this.remindersLabel,
  });

  final bool darkModeEnabled;
  final bool notificationsEnabled;
  final String remindersLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preferences',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tune the app to your working rhythm.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(label: darkModeEnabled ? 'Dark mode on' : 'Light mode'),
              _HeroChip(label: notificationsEnabled ? 'Notifications on' : 'Notifications off'),
              _HeroChip(label: 'Reminders $remindersLabel'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      side: BorderSide.none,
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({
    required this.appName,
    required this.version,
    required this.framework,
    required this.developer,
    required this.tagline,
  });

  final String appName;
  final String version;
  final String framework;
  final String developer;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: colorScheme.secondaryContainer,
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  version,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  framework,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  developer,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  tagline,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
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
