import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_widgets.dart';
import '../repositories/household_repository.dart';
import '../viewmodels/household_actions.dart';
import '../viewmodels/session_view_model.dart';

String actionError(AppLocalizations l, String? code) => switch (code) {
  'expired_invitation' => l.invitationExpired,
  'revoked_invitation' => l.invitationRevoked,
  'invitation_limit' => l.invitationLimit,
  'rate_limit' => l.invitationRateLimit,
  'invalid_invitation' => l.invitationUnavailable,
  'forbidden' => l.permissionDenied,
  _ => l.operationFailed,
};

class MembershipView extends StatelessWidget {
  const MembershipView({required this.mode, super.key});
  final String mode;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => HouseholdActions(context.read<HouseholdRepository>()),
    child: _MembershipContent(mode: mode),
  );
}

class _MembershipContent extends StatefulWidget {
  const _MembershipContent({required this.mode});
  final String mode;
  @override
  State<_MembershipContent> createState() => _MembershipContentState();
}

class _MembershipContentState extends State<_MembershipContent> {
  final code = TextEditingController();
  final name = TextEditingController();
  final description = TextEditingController();
  final form = GlobalKey<FormState>();
  late final String? householdId;
  @override
  void initState() {
    super.initState();
    final session = context.read<SessionViewModel>();
    householdId = session.activeHousehold?.id;
    name.text = session.activeHousehold?.name ?? '';
    description.text = session.activeHousehold?.description ?? '';
    Future.microtask(() async {
      if (!mounted) return;
      final vm = context.read<HouseholdActions>();
      switch (widget.mode) {
        case 'invite':
          await vm.loadInvitations(householdId!);
        case 'settings' || 'members':
          await vm.loadMembers(householdId!);
        case 'profile':
          if (await vm.loadProfile()) {
            name.text = vm.profile?['display_name'] as String? ?? '';
          }
      }
    });
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<bool> confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) {
          final l = AppLocalizations.of(context)!;
          return AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.confirm),
              ),
            ],
          );
        },
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HouseholdActions>();
    final session = context.watch<SessionViewModel>();
    final l = AppLocalizations.of(context)!;
    final title = switch (widget.mode) {
      'join' => l.joinHousehold,
      'invite' => l.inviteFamily,
      'profile' => l.profile,
      'settings' => l.householdSettings,
      _ => l.familyMembers,
    };
    return AppScaffold(
      title: title,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (vm.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AppErrorState(
                    message: actionError(l, vm.error),
                    onRetry: vm.busy
                        ? null
                        : () {
                            if (widget.mode == 'invite') {
                              vm.loadInvitations(householdId!);
                            }
                            if (widget.mode == 'profile') {
                              vm.loadProfile().then((ok) {
                                if (ok && mounted) {
                                  name.text =
                                      vm.profile?['display_name'] as String? ??
                                      '';
                                }
                              });
                            }
                            if (widget.mode == 'members' ||
                                widget.mode == 'settings') {
                              vm.loadMembers(householdId!);
                            }
                          },
                  ),
                ),
              if (widget.mode == 'join') ...[
                const CircleAvatar(
                  radius: 40,
                  child: Icon(Icons.group_add_outlined, size: 40),
                ),
                const SizedBox(height: 24),
                Text(l.joinHomeDescription),
                const SizedBox(height: 24),
                TextField(
                  controller: code,
                  enabled: !vm.busy,
                  onChanged: (_) => vm.clearPreview(),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 100,
                  decoration: InputDecoration(labelText: l.invitationCode),
                ),
                AppPrimaryButton(
                  label: l.previewInvitation,
                  loading: vm.busy,
                  onPressed: code.text.trim().isEmpty
                      ? null
                      : () => vm.previewCode(code.text.trim()),
                ),
                if (vm.preview != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            vm.preview!.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            vm.preview!.alreadyMember
                                ? l.alreadyMember
                                : l.joinConfirmation,
                          ),
                          const SizedBox(height: 16),
                          AppPrimaryButton(
                            label: l.joinHousehold,
                            loading: vm.busy,
                            onPressed: () async {
                              final entered = code.text.trim();
                              String? id;
                              final ok = await vm.run(() async {
                                id = (await vm.repository.redeem(entered)).id;
                              });
                              if (ok && mounted) {
                                await session.selectHousehold(id!);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (widget.mode == 'invite') ...[
                Text(
                  session.activeHousehold?.name ?? '',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(l.codeShownOnce),
                const SizedBox(height: 16),
                if (vm.issued != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          SelectableText(
                            vm.issued!.code,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.copy),
                                label: Text(l.copyCode),
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: vm.issued!.code),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(l.copied)),
                                    );
                                  }
                                },
                              ),
                              Builder(
                                builder: (context) => TextButton.icon(
                                  icon: const Icon(Icons.share),
                                  label: Text(l.shareInvitation),
                                  onPressed: () async {
                                    final box =
                                        context.findRenderObject()!
                                            as RenderBox;
                                    try {
                                      await SharePlus.instance.share(
                                        ShareParams(
                                          text: l.invitationShare(
                                            session.activeHousehold!.name,
                                            vm.issued!.code,
                                          ),
                                          sharePositionOrigin:
                                              box.localToGlobal(Offset.zero) &
                                              box.size,
                                        ),
                                      );
                                    } on Object {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(l.operationFailed),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                AppPrimaryButton(
                  label: l.generateCode,
                  loading: vm.busy,
                  onPressed: () async {
                    if (vm.invitations.any(
                          (i) =>
                              !i.revoked && i.expiresAt.isAfter(DateTime.now()),
                        ) &&
                        !await confirm(l.replaceCodeQuestion)) {
                      return;
                    }
                    if (mounted) await vm.issue(householdId!);
                  },
                ),
                const SizedBox(height: 24),
                if (vm.invitations.isEmpty && !vm.busy) Text(l.noInvitations),
                for (final invite in vm.invitations)
                  Card(
                    child: ListTile(
                      title: Text(
                        invite.revoked
                            ? l.revoked
                            : invite.expiresAt.isBefore(DateTime.now())
                            ? l.expired
                            : invite.maxUses != null &&
                                  invite.uses >= invite.maxUses!
                            ? l.invitationLimit
                            : l.active,
                      ),
                      subtitle: Text(
                        '${l.expires}: ${MaterialLocalizations.of(context).formatMediumDate(invite.expiresAt.toLocal())}\n${l.uses}: ${invite.uses} / ${invite.maxUses ?? "∞"}',
                      ),
                      trailing: invite.revoked
                          ? null
                          : IconButton(
                              tooltip: l.revokeCode,
                              onPressed: vm.busy
                                  ? null
                                  : () async {
                                      if (await confirm(l.revokeCodeQuestion) &&
                                          mounted) {
                                        await vm.revoke(
                                          householdId!,
                                          invite.id,
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.block),
                            ),
                    ),
                  ),
                TextButton(
                  onPressed: () {
                    session.finishInvitation();
                    context.goNamed('home');
                  },
                  child: Text(l.done),
                ),
              ],
              if (widget.mode == 'settings' || widget.mode == 'profile')
                Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        child: Icon(
                          widget.mode == 'profile'
                              ? Icons.person_outline
                              : Icons.home_outlined,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(child: Text(l.profileAvatar)),
                      const SizedBox(height: 24),
                      if (widget.mode == 'profile')
                        Text(
                          vm.profile?['email'] as String? ??
                              session.user?.email ??
                              '',
                        ),
                      TextFormField(
                        controller: name,
                        maxLength: 100,
                        decoration: InputDecoration(
                          labelText: widget.mode == 'profile'
                              ? l.fullName
                              : l.householdName,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? l.requiredField
                            : null,
                      ),
                      if (widget.mode == 'settings')
                        TextFormField(
                          controller: description,
                          maxLength: 1000,
                          maxLines: 3,
                          decoration: InputDecoration(labelText: l.description),
                        ),
                      const SizedBox(height: 16),
                      AppPrimaryButton(
                        label: l.saveChanges,
                        loading: vm.busy,
                        onPressed:
                            widget.mode == 'profile' && vm.profile == null
                            ? null
                            : () async {
                                if (!form.currentState!.validate()) return;
                                final ok = widget.mode == 'profile'
                                    ? await vm.saveProfile(name.text)
                                    : await vm.update(
                                        householdId!,
                                        name.text,
                                        description.text.trim(),
                                      );
                                if (ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        widget.mode == 'profile'
                                            ? l.profileSaved
                                            : l.settingsSaved,
                                      ),
                                    ),
                                  );
                                  if (widget.mode == 'settings') {
                                    await session.refresh();
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ),
              if (widget.mode == 'members' || widget.mode == 'settings') ...[
                const SizedBox(height: 24),
                Text(
                  l.familyMembers,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final member in vm.members)
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(member.name),
                    subtitle: Text(
                      member.role == 'admin' ? l.adminRole : l.memberRole,
                    ),
                  ),
                if (vm.moreMembers)
                  TextButton(
                    onPressed: vm.busy
                        ? null
                        : () => vm.loadMembers(householdId!),
                    child: Text(l.loadMore),
                  ),
              ],
              if (widget.mode == 'profile') ...[
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: Text(session.activeHousehold?.name ?? ''),
                  trailing: const Icon(Icons.swap_horiz),
                  onTap: () => context.goNamed('selectHousehold'),
                ),
                TextButton(onPressed: session.logout, child: Text(l.logout)),
              ],
              if (vm.busy)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: AppLoadingIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
