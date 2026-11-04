import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../household/viewmodels/session_view_model.dart';
import '../viewmodels/diagnostics_view_model.dart';

class HomeView extends StatelessWidget {
  const HomeView({this.profile = false, super.key});
  final bool profile;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final session = context.watch<SessionViewModel>();
    final diagnostics = context.watch<DiagnosticsViewModel>();
    return AppScaffold(
      title: profile ? l.profile : l.home,
      body: ListView(
        padding: const EdgeInsetsDirectional.all(24),
        children: [
          Text(
            session.activeHousehold?.name ?? '',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(l.placeholder),
          const SizedBox(height: 24),
          AppSecondaryButton(
            label: l.switchHousehold,
            onPressed: () => context.goNamed('selectHousehold'),
          ),
          const SizedBox(height: 8),
          if (profile) ...[
            Text(session.user?.email ?? ''),
            AppPrimaryButton(label: l.logout, onPressed: session.logout),
          ] else ...[
            for (final item in [
              (l.familyMembers, 'members'),
              (l.shopping, 'shopping'),
              (l.notifications, 'notifications'),
              (l.familyActivity, 'familyActivity'),
              (l.addInventory, 'addInventory'),
              (l.createTask, 'createTask'),
              if (session.activeHousehold?.role == 'admin')
                (l.householdSettings, 'householdSettings'),
              if (session.activeHousehold?.role == 'admin')
                (l.inviteFamily, 'inviteFamily'),
            ])
              ListTile(
                title: Text(item.$1),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.goNamed(item.$2),
              ),
          ],
          const SizedBox(height: 24),
          AppSecondaryButton(
            label: l.checkApi,
            onPressed: diagnostics.busy ? null : () => diagnostics.check(),
          ),
          const SizedBox(height: 8),
          AppSecondaryButton(
            label: l.checkProfile,
            onPressed: diagnostics.busy
                ? null
                : () => diagnostics.check(authenticated: true),
          ),
          if (diagnostics.busy) const AppLoadingIndicator(),
          if (diagnostics.success != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 16),
              child: Text(
                diagnostics.success!
                    ? (diagnostics.profile
                          ? l.profileConnected
                          : l.apiConnected)
                    : l.apiUnavailable,
              ),
            ),
        ],
      ),
    );
  }
}
