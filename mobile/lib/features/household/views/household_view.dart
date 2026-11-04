import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_widgets.dart';
import '../viewmodels/session_view_model.dart';

class HouseholdSelectionView extends StatelessWidget {
  const HouseholdSelectionView({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final vm = context.watch<SessionViewModel>();
    return AppScaffold(
      title: l.selectHousehold,
      actions: [
        IconButton(
          onPressed: vm.logout,
          tooltip: l.logout,
          icon: const Icon(Icons.logout),
        ),
      ],
      body: vm.switching
          ? const AppLoadingIndicator()
          : ListView(
              padding: const EdgeInsetsDirectional.all(24),
              children: [
                if (vm.errorCode != null)
                  AppErrorState(message: l.householdError, onRetry: vm.refresh),
                if (vm.households.isEmpty && vm.errorCode == null)
                  AppEmptyState(message: l.noHouseholds),
                for (final household in vm.households)
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.home_outlined),
                    ),
                    title: Text(household.name),
                    subtitle: Text(
                      l.memberSummary(
                        household.memberCount,
                        household.role == 'admin' ? l.adminRole : l.memberRole,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    selected: vm.activeHousehold?.id == household.id,
                    onTap: () async {
                      await vm.selectHousehold(household.id);
                      if (context.mounted && vm.activeHousehold != null) {
                        context.goNamed('home');
                      }
                    },
                  ),
                const SizedBox(height: 24),
                for (final option in [
                  (
                    Icons.add_home_outlined,
                    l.createHousehold,
                    l.createHomeDescription,
                    'createHousehold',
                  ),
                  (
                    Icons.group_add_outlined,
                    l.joinHousehold,
                    l.joinHomeDescription,
                    'joinHousehold',
                  ),
                ])
                  Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.goNamed(option.$4),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 28,
                              child: Icon(option.$1, size: 28),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              option.$2,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(option.$3),
                            const SizedBox(height: 16),
                            const Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Icon(Icons.arrow_forward),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class CreateHouseholdView extends StatefulWidget {
  const CreateHouseholdView({super.key});
  @override
  State<CreateHouseholdView> createState() => _CreateHouseholdViewState();
}

class _CreateHouseholdViewState extends State<CreateHouseholdView> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final vm = context.watch<SessionViewModel>();
    return AppScaffold(
      title: l.createHousehold,
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Form(
          key: _form,
          child: Column(
            children: [
              const CircleAvatar(
                radius: 40,
                child: Icon(Icons.home_outlined, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                l.prepareHome,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              AppTextField(
                label: l.householdName,
                controller: _name,
                validator: (value) =>
                    value == null ||
                        value.trim().isEmpty ||
                        value.trim().length > 100
                    ? l.requiredField
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                maxLength: 1000,
                maxLines: 3,
                decoration: InputDecoration(labelText: l.description),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(l.adminNotice),
                    subtitle: Text(l.adminDescription),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (vm.errorCode != null)
                AppErrorState(message: l.householdError),
              AppPrimaryButton(
                label: l.createHousehold,
                loading: vm.switching,
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  await vm.createHousehold(
                    _name.text,
                    description: _description.text.trim(),
                  );
                  if (context.mounted && vm.activeHousehold != null) {
                    context.goNamed('inviteFamily');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
