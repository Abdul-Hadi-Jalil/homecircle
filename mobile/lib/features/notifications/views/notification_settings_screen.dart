import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../dashboard/widgets/hub_widgets.dart';
import '../../tasks/widgets/task_widgets.dart';
import '../services/push_service.dart';
import '../viewmodels/notifications_viewmodel.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        unawaited(context.read<NotificationsViewModel>().loadPreferences());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.taskCopy, vm = context.watch<NotificationsViewModel>();
    return AppScaffold(
      title: l.hubNotifySettings,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            vm.session.activeHousehold?.name ?? '',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (vm.preferencesBusy) const LinearProgressIndicator(),
          if (vm.preferencesCached) Text(l.hubCached),
          if (vm.error != null) Text(hubError(context, vm.error)),
          if (vm.cacheError) Text(l.chatCacheError),
          if (vm.preferences.isNotEmpty)
            for (final entry in [
              ('tasks_enabled', l.hubTaskUpdates),
              ('shopping_enabled', l.hubShoppingUpdates),
              ('inventory_enabled', l.hubInventoryAlerts),
              ('chat_enabled', l.hubChatUpdates),
              ('mentions_enabled', l.hubMentions),
              ('push_enabled', l.hubPush),
            ])
              SwitchListTile(
                title: Text(entry.$2),
                value: vm.preferences[entry.$1] as bool? ?? true,
                onChanged: vm.preferencesBusy
                    ? null
                    : (value) async {
                        final saved = await vm.setPreference(entry.$1, value);
                        if (saved && context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(l.hubSaved)));
                        }
                      },
              ),
          const SizedBox(height: 24),
          Text(l.hubPushExplanation),
          const SizedBox(height: 12),
          Text(switch (vm.permission) {
            PushPermission.unavailable => l.hubPushUnavailable,
            PushPermission.denied => l.hubPushDenied,
            PushPermission.authorized => l.hubPushAllowed,
            _ => l.hubPushExplanation,
          }),
          if (vm.push.available && vm.permission != PushPermission.authorized)
            FilledButton(
              onPressed: vm.requestPermission,
              child: Text(l.hubEnablePush),
            ),
          TextButton(onPressed: vm.loadPreferences, child: Text(l.taskRefresh)),
        ],
      ),
    );
  }
}
